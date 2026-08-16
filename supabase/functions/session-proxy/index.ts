// Edge Function: session-proxy — Fala 2A.2 (PERSISTENCJA), Dyrektywa 02.
// Osobna funkcja (Nota N2). Jedna odpowiedzialność: bezpieczna persistencja
// sesji/raportów PO STRONIE SERWERA. NIE wywołuje LLM (Q3).
//
// Endpointy (wyłącznie własne sesje — ownership gate W KODZIE, §9):
//   POST   /sessions          → utworzenie sesji (completed) + messages + report
//   GET    /sessions          → historia własnych sesji (retencja 90 dni, malejąco)
//   GET    /sessions/:id      → własna sesja + raport (obca → 404, bez ujawniania istnienia)
//   DELETE /sessions/:id      → własna sesja (kaskada messages+reports); obca → 404
//
// Bezpieczeństwo:
//   - verify_jwt = true → platforma odrzuca forged JWT (401) PRZED kodem (Gate 0).
//   - JWT.sub jest JEDYNĄ tożsamością użytkownika (§7). user_id/session_id w body → 422.
//   - service_role omija RLS → brama ownership żyje w kodzie funkcji (sub == row.user_id).
//   - Walidacja raportu server-side PRZED INSERT (§3): 422 INVALID_REPORT, zero wierszy.
//   - Polityka transkryptu (§12/§14): persystujemy wyłącznie wypowiedzi użytkownika
//     (sender='user' wymuszane serwerowo). MODEL_OUTPUT ≠ USER_FACT.
//   - Retencja (§17/Q2): odczyt wyklucza sesje starsze niż 90 dni. Fizyczny purge → 2E.
//
// Serializacja tablic raportu (§6) — deterministyczna i odwracalna:
//   strengths: string[]     → reports.strengths      (JSON.stringify — tablica tekstu)
//   gaps: string[]          → reports.gaps           (JSON.stringify)
//   action_items: string[]  → reports.action_items   (JSON.stringify)
//   overall_rating: int 1–5 → reports.overall_rating (int; DB CHECK BETWEEN 1 AND 5)
//   Odwrotne mapowanie dla 2A.3 (VIEW): JSON.parse(reports.strengths) itd.
//
// Transakcja (§2.2): walidacja całości PRZED jakimkolwiek INSERT; następnie
// sesja → messages → report; w razie błędu po wstawieniu sesji cofamy przez
// DELETE sesji (kaskada WP1 usuwa dzieci). Brak nowych zależności/schematu.

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

const CORS_ORIGINS = (() => {
  const raw = Deno.env.get("CORS_ORIGINS") ??
    "http://localhost:8899,http://localhost:3000";
  return raw.split(",").map((s) => s.trim()).filter((s) => s.length > 0);
})();

// Retencja 90 dni (§17, Q2) — wykluczenie w endpointach odczytu.
const RETENTION_DAYS = 90;

function json(data: unknown, status = 200, headers: HeadersInit = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...headers,
    },
  });
}

function corsResponse() {
  const origin = CORS_ORIGINS.join(", ");
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "POST, GET, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };
}

function safeErrorMessage(e: unknown) {
  const msg = e instanceof Error ? e.message : String(e);
  const sanitized = msg
    .replace(/AIza[0-9A-Za-z_\-]{35}/g, "[REDACTED]")
    .replace(/sk-[A-Za-z0-9_\-]{20,}/g, "[REDACTED]")
    .replace(/eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+/g, "[REDACTED]");
  if (sanitized.length > 200) return sanitized.slice(0, 200) + "...";
  return sanitized;
}

class ApiUpstreamError extends Error {
  status: number;
  code: string;
  constructor(status: number, code: string) {
    super(code);
    this.status = status;
    this.code = code;
  }
}

/// Wyciągnięcie sub z JWT. Platforma (verify_jwt) zweryfikowała podpis PRZED
/// kodem funkcji; tutaj jedynie parsujemy payload — nie wierzymy body.
/// Obsługa base64url (JWT), spójnie z pozostałymi proxy.
function extractSub(authHeader: string): string | null {
  if (!authHeader.startsWith("Bearer ")) return null;
  const token = authHeader.slice("Bearer ".length);
  const payloadPart = token.split(".")[1];
  if (!payloadPart) return null;
  try {
    const b64 = payloadPart.replace(/-/g, "+").replace(/_/g, "/");
    const padded = b64.padEnd(b64.length + ((4 - (b64.length % 4)) % 4), "=");
    const decoded = JSON.parse(atob(padded));
    return typeof decoded.sub === "string" ? decoded.sub : null;
  } catch {
    return null;
  }
}

/// Zasada §7: klient NIE może dostarczyć user_id jako autorytatywnego pola.
/// Obecność user_id/session_id w body = 422 USER_ID_FORBIDDEN (odrzucamy jawnie).
function assertNoIdentityInBody(body: Record<string, unknown>): void {
  for (const key of ["user_id", "session_id"]) {
    if (key in body && body[key] !== null && body[key] !== undefined) {
      throw new ApiUpstreamError(422, "USER_ID_FORBIDDEN");
    }
  }
}

/// Walidacja kontraktu raportu (§3) server-side PRZED INSERT.
/// strengths/gaps/action_items: tablice stringów; overall_rating: int 1–5.
/// Niepoprawny → 422 INVALID_REPORT (zero wierszy).
type ReportContract = {
  strengths: string[];
  gaps: string[];
  action_items: string[];
  overall_rating: number;
};

function validateReportContract(raw: unknown): ReportContract {
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    throw new ApiUpstreamError(422, "INVALID_REPORT");
  }
  const r = raw as Record<string, unknown>;

  const readArray = (key: string): string[] => {
    const v = r[key];
    if (!Array.isArray(v)) throw new ApiUpstreamError(422, "INVALID_REPORT");
    if (!v.every((x) => typeof x === "string")) {
      throw new ApiUpstreamError(422, "INVALID_REPORT");
    }
    return v as string[];
  };

  const strengths = readArray("strengths");
  const gaps = readArray("gaps");
  const action_items = readArray("action_items");

  const rating = r["overall_rating"];
  if (typeof rating !== "number" || !Number.isInteger(rating)) {
    throw new ApiUpstreamError(422, "INVALID_REPORT");
  }
  if (rating < 1 || rating > 5) throw new ApiUpstreamError(422, "INVALID_REPORT");

  return { strengths, gaps, action_items, overall_rating: rating };
}

/// Serializacja tablic (§6) — deterministyczna, odwracalna pod 2A.3.
function serializeArray(arr: string[]): string {
  return JSON.stringify(arr);
}

/// Typ wiersza raportu z DB (kolumny tekstowe — serializacja JSON z §6).
type ReportRow = {
  strengths: string | null;
  gaps: string | null;
  action_items: string | null;
  overall_rating: number;
};

/// Odczytywanie jednej sesji (własnej) — wspólny helper GET /sessions/:id.
/// Obca / nieistniejąca / starsza niż retencja → 404 (nie ujawniamy istnienia).
async function readOwnSession(
  client: SupabaseClient<any>,
  userId: string,
  sessionId: string,
) {
  const cutoff = new Date(Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000).toISOString();
  const { data: session, error } = await client
    .from("sessions")
    .select("id, scenario_key, title, status, created_at, completed_at")
    .eq("id", sessionId)
    .eq("user_id", userId)
    .gte("created_at", cutoff)
    .maybeSingle();
  if (error || !session) return null;

  const { data: report } = await client
    .from("reports")
    .select("strengths, gaps, action_items, overall_rating")
    .eq("session_id", sessionId)
    .eq("user_id", userId)
    .maybeSingle();

  let reportData: ReportContract | null = null;
  if (report) {
    const row = report as ReportRow;
    reportData = {
      strengths: JSON.parse(row.strengths ?? "[]"),
      gaps: JSON.parse(row.gaps ?? "[]"),
      action_items: JSON.parse(row.action_items ?? "[]"),
      overall_rating: row.overall_rating,
    };
  }
  return { session, report: reportData };
}

Deno.serve(async (req) => {
  const headers = corsResponse();
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const userId = extractSub(authHeader);
    if (!userId) {
      return json({ error: "UNAUTHORIZED" }, 401, headers);
    }

    // Parsowanie ścieżki: POST/GET /sessions, GET/DELETE /sessions/:id.
    const url = new URL(req.url);
    const parts = url.pathname.split("/").filter(Boolean);
    const idx = parts.indexOf("session-proxy");
    const rest = idx >= 0 ? parts.slice(idx + 1) : parts;

    const isSessionsRoot = rest.length === 1 && rest[0] === "sessions";
    const isSessionsItem = rest.length === 2 && rest[0] === "sessions";
    const sessionId = isSessionsItem ? rest[1] : null;

    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const client = createClient(supabaseUrl, serviceRoleKey);

    // ---- POST /sessions — utworzenie sesji (completed) + messages + report ----
    if (req.method === "POST" && isSessionsRoot) {
      let body: Record<string, unknown>;
      try {
        const parsed: unknown = JSON.parse(await req.text());
        if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
          throw new Error("not-object");
        }
        body = parsed as Record<string, unknown>;
      } catch {
        return json({ error: "INVALID_JSON" }, 422, headers);
      }
      assertNoIdentityInBody(body);

      const scenarioKey = body["scenario_key"];
      if (typeof scenarioKey !== "string" || scenarioKey.trim().length === 0) {
        return json({ error: "MISSING_SCENARIO_KEY" }, 422, headers);
      }
      const title = body["title"];
      if (title !== undefined && title !== null && typeof title !== "string") {
        return json({ error: "INVALID_TITLE" }, 422, headers);
      }
      const userStatements = body["user_statements"];
      if (
        !Array.isArray(userStatements) ||
        !userStatements.every((s) => typeof s === "string")
      ) {
        return json({ error: "INVALID_USER_STATEMENTS" }, 422, headers);
      }

      // Walidacja kontraktu raportu PRZED jakimkolwiek INSERT (§3): 422 + zero wierszy.
      const reportContract = validateReportContract(body["report"]);

      // 1) INSERT session (status completed, completed_at now()).
      const { data: session, error: sessionError } = await client
        .from("sessions")
        .insert({
          user_id: userId,
          scenario_key: scenarioKey.trim(),
          title: typeof title === "string" ? title.trim() : null,
          status: "completed",
          completed_at: new Date().toISOString(),
        })
        .select("id")
        .single();
      if (sessionError || !session) {
        return json({ error: "DB_ERROR" }, 503, headers);
      }
      const newSessionId = session.id as string;

      try {
        // 2) INSERT messages — polityka transkryptu (§12): wyłącznie wypowiedzi
        //    użytkownika, sender='user' WYMUSZANE serwerowo (klient nie dostarcza).
        const messageRows = (userStatements as string[]).map((content) => ({
          session_id: newSessionId,
          user_id: userId,
          sender: "user",
          content,
        }));
        if (messageRows.length > 0) {
          const { error: messagesError } = await client
            .from("messages")
            .insert(messageRows);
          if (messagesError) throw new ApiUpstreamError(503, "DB_ERROR");
        }

        // 3) INSERT report — serializacja tablic (§6).
        const { error: reportError } = await client
          .from("reports")
          .insert({
            session_id: newSessionId,
            user_id: userId,
            strengths: serializeArray(reportContract.strengths),
            gaps: serializeArray(reportContract.gaps),
            action_items: serializeArray(reportContract.action_items),
            overall_rating: reportContract.overall_rating,
          });
        if (reportError) throw new ApiUpstreamError(503, "DB_ERROR");
      } catch (e) {
        // Transakcja: błąd po INSERT sesji → cofamy przez kaskadę (WP1).
        await client.from("sessions").delete().eq("id", newSessionId);
        throw e;
      }

      return json({ ok: true, session_id: newSessionId }, 201, headers);
    }

    // ---- GET /sessions — historia własnych sesji (retencja 90d, malejąco) ----
    if (req.method === "GET" && isSessionsRoot) {
      const cutoff = new Date(Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000).toISOString();
      const { data, error } = await client
        .from("sessions")
        .select("id, scenario_key, title, status, created_at, completed_at")
        .eq("user_id", userId)
        .gte("created_at", cutoff)
        .order("created_at", { ascending: false });
      if (error) return json({ error: "DB_ERROR" }, 503, headers);
      return json({ sessions: data ?? [] }, 200, headers);
    }

    // ---- GET /sessions/:id — własna sesja + raport ----
    if (req.method === "GET" && isSessionsItem && sessionId) {
      const own = await readOwnSession(client, userId, sessionId);
      if (!own) return json({ error: "SESSION_NOT_FOUND" }, 404, headers);
      return json(own, 200, headers);
    }

    // ---- DELETE /sessions/:id — własna; kaskada messages+reports (WP1) ----
    if (req.method === "DELETE" && isSessionsItem && sessionId) {
      const { data: deleted, error } = await client
        .from("sessions")
        .delete()
        .eq("id", sessionId)
        .eq("user_id", userId)
        .select("id");
      if (error) return json({ error: "DB_ERROR" }, 503, headers);
      if (!deleted || deleted.length === 0) {
        return json({ error: "SESSION_NOT_FOUND" }, 404, headers);
      }
      return json({ ok: true }, 200, headers);
    }

    return json({ error: "NOT_FOUND" }, 404, headers);
  } catch (e) {
    if (e instanceof ApiUpstreamError) {
      return json({ error: e.code }, e.status, headers);
    }
    return json({ error: "INTERNAL_ERROR" }, 503, headers);
  }
});