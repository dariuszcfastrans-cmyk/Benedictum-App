// Edge Function: session-proxy — Fala 2A (Dyrektywa 02).
// Osobna funkcja (Nota N2). Jedna odpowiedzialność: bezpieczna persistencja
// sesji/raportów PO STRONIE SERWERA. NIE wywołuje LLM (Q3).
//
// W 2A.1 (REPORT): szkielet warstwy tożsamości i bezpieczeństwa:
//   - verify_jwt = true (config.toml) → platforma odrzuca forged JWT (401)
//     PRZED kodem funkcji (wzorzec Gate 0).
//   - JWT.sub jest JEDYNĄ tożsamością użytkownika (invariant §7).
//   - user_id z body jest ZABRONIONE (klient NIE dostarcza tożsamości).
//   - zero wywołań LLM.
// Endpointy persistencji (INSERT / historia / VIEW / DELETE / retencja)
// wchodzą w 2A.2 — NIE w 2A.1.

const CORS_ORIGINS = (() => {
  const raw = Deno.env.get("CORS_ORIGINS") ??
    "http://localhost:8899,http://localhost:3000";
  return raw.split(",").map((s) => s.trim()).filter((s) => s.length > 0);
})();

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
    "Access-Control-Allow-Methods": "POST, OPTIONS",
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
function extractSub(authHeader: string): string | null {
  if (!authHeader.startsWith("Bearer ")) return null;
  const token = authHeader.slice("Bearer ".length);
  const payloadPart = token.split(".")[1];
  if (!payloadPart) return null;
  try {
    const decoded = JSON.parse(atob(payloadPart));
    return typeof decoded.sub === "string" ? decoded.sub : null;
  } catch {
    return null;
  }
}

/// Zasada §7: klient NIE może dostarczyć user_id jako autorytatywnego pola.
/// Obecność user_id w body = 422 USER_ID_FORBIDDEN (odrzucamy jawnie).
function assertNoUserIdInBody(body: Record<string, unknown>): void {
  if ("user_id" in body && body.user_id !== null && body.user_id !== undefined) {
    throw new ApiUpstreamError(422, "USER_ID_FORBIDDEN");
  }
}

Deno.serve(async (req) => {
  const headers = corsResponse();
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers });
  }
  if (req.method !== "POST") {
    return json({ error: "METHOD_NOT_ALLOWED" }, 405, headers);
  }

  try {
    // Identity: wyłącznie JWT.sub (verify_jwt wykonało 401 przed kodem dla
    // forged JWT). Brak Bearer → 401 defensywnie.
    const authHeader = req.headers.get("Authorization") ?? "";
    const userId = extractSub(authHeader);
    if (!userId) {
      return json({ error: "UNAUTHORIZED" }, 401, headers);
    }

    // Body musi być obiektem JSON (jeśli obecne). 2A.1: brak user_id z body.
    let body: Record<string, unknown> = {};
    const raw = await req.text();
    if (raw.trim().length > 0) {
      try {
        const parsed: unknown = JSON.parse(raw);
        if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
          throw new Error("not-object");
        }
        body = parsed as Record<string, unknown>;
      } catch {
        return json({ error: "INVALID_JSON" }, 422, headers);
      }
    }
    assertNoUserIdInBody(body);

    // 2A.1: szkielet — sonda tożsamości (verify_jwt + JWT.sub + zakaz user_id).
    // Endpointy persistencji: 2A.2.
    return json({ ok: true, user: userId }, 200, headers);
  } catch (e) {
    if (e instanceof ApiUpstreamError) {
      return json({ error: e.code }, e.status, headers);
    }
    return json({ error: "INTERNAL_ERROR" }, 503, headers);
  }
});