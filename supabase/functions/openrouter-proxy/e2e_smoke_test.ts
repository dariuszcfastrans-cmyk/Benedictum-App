// E2E smoke-test (online, prod cloud) — Fala 2B, wariant C (trwały artefakt).
// Testuje PEŁNY łańcuch: JWT auth → openrouter-proxy (LLM, mode:"report")
// → session-proxy POST/GET/DELETE /sessions → czystość (404 po DELETE).
// Bazuje na jednorazowym teście Fali 2B (7/7 PASS, 2026-08-17) — utrwala wartość.
//
// Wymagania uruchomienia:
//   - dostęp do cloudu Benedictum (produkcyjny SUPABASE_URL),
//   - konto testowe (BENEDICTUM_TEST_EMAIL / BENEDICTUM_TEST_PASSWORD),
//   - klucz anon (SUPABASE_ANON_KEY).
//   Zmienne brane z env; jeśli brak — próba odczytu z pliku env (HOME/.env.dci).
//
// Uruchom:
//   deno test --allow-net --allow-env --allow-read supabase/functions/openrouter-proxy/e2e_smoke_test.ts
//
// Bezpieczeństwo:
//   - klucze/logowanie wyłącznie przez env — nigdy w repo ani w logach,
//   - wyłącznie syntetyczny materiał testowy (bez PII),
//   - test czyści po sobie (DELETE sesji), z potwierdzeniem 404,
//   - user_id/session_id czytane z odpowiedzi, nie hardcoded.

import { assert, assertEquals } from "jsr:@std/assert";

function loadEnv(): Record<string, string> {
  const env: Record<string, string> = {};
  const home = Deno.env.get("HOME") ?? "";
  const path = `${home}/.env.dci`;
  try {
    const text = Deno.readTextFileSync(path);
    for (const line of text.split("\n")) {
      const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
      if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, "");
    }
  } catch {
    // brak pliku env — polegamy na zmiennych procesowych
  }
  return env;
}

const fileEnv = loadEnv();

const SUPABASE_URL = Deno.env.get("TEST_SUPABASE_URL") ??
  fileEnv.SUPABASE_URL ?? "";
const ANON_KEY = Deno.env.get("TEST_SUPABASE_ANON_KEY") ??
  fileEnv.SUPABASE_ANON_KEY ?? "";
const EMAIL = Deno.env.get("TEST_EMAIL") ?? fileEnv.BENEDICTUM_TEST_EMAIL ?? "";
const PASSWORD = Deno.env.get("TEST_PASSWORD") ??
  fileEnv.BENEDICTUM_TEST_PASSWORD ?? "";

if (!SUPABASE_URL || !ANON_KEY || !EMAIL || !PASSWORD) {
  throw new Error(
    "Brak danych cloud (TEST_SUPABASE_URL / TEST_SUPABASE_ANON_KEY / TEST_EMAIL / TEST_PASSWORD).",
  );
}

const FN_BASE = `${SUPABASE_URL}/functions/v1`;

async function signIn(): Promise<string> {
  const res = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: ANON_KEY, "Content-Type": "application/json" },
    body: JSON.stringify({ email: EMAIL, password: PASSWORD }),
  });
  assertEquals(res.status, 200, `auth status=${res.status}`);
  const body = await res.json();
  assert(body.access_token, "brak access_token");
  return body.access_token as string;
}

function decodeSub(jwt: string): string {
  const payload = jwt.split(".")[1];
  const b64 = payload.replace(/-/g, "+").replace(/_/g, "/");
  const padded = b64.padEnd(b64.length + ((4 - (b64.length % 4)) % 4), "=");
  const decoded = JSON.parse(atob(padded));
  return decoded.sub as string;
}

Deno.test("E2E online: auth + openrouter-proxy report + session-proxy lifecycle", async () => {
  const jwt = await signIn();
  assert(decodeSub(jwt).length > 0, "sub powinno istnieć");

  // 1) openrouter-proxy mode:"report" — 1 wywołanie LLM, kontrakt raportu.
  const scenario = "SYNTETYCZNY-E2E: negocjacja ceny kontraktu usługowego (bez PII)";
  const context =
    "Klient: firma syntetyczna. User: 'Chce obnizyc cene o 15%'. Coach poprowadzil wywiad.";
  const repRes = await fetch(`${FN_BASE}/openrouter-proxy`, {
    method: "POST",
    headers: { Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
    body: JSON.stringify({ mode: "report", scenario, context }),
  });
  assertEquals(repRes.status, 200, `openrouter-proxy status=${repRes.status}`);
  const repBody = await repRes.json();
  const report = repBody.report;
  assert(report, "brak report");
  assertEquals(typeof report.overall_rating, "number");
  assert(Number.isInteger(report.overall_rating) && report.overall_rating >= 1 &&
    report.overall_rating <= 5, "overall_rating poza zakresem 1-5");
  for (const key of ["strengths", "gaps", "action_items"]) {
    assert(Array.isArray(report[key]) && report[key].every((x: unknown) => typeof x === "string"),
      `${key} nie jest tablicą stringów`);
  }

  // 2) session-proxy POST /sessions — persistencja.
  const postRes = await fetch(`${FN_BASE}/session-proxy/sessions`, {
    method: "POST",
    headers: { Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      scenario_key: "SYNTETYCZNY-E2E",
      title: "E2E smoke test",
      user_statements: ["Chce obnizyc cene o 15%", "Moge zaplacic w 30 dni"],
      report,
    }),
  });
  assertEquals(postRes.status, 201, `POST status=${postRes.status}`);
  const postBody = await postRes.json();
  const sessionId = postBody.session_id as string;
  assert(sessionId, "brak session_id");

  try {
    // 3) GET /sessions — historia zawiera nową sesję.
    const listRes = await fetch(`${FN_BASE}/session-proxy/sessions`, {
      headers: { Authorization: `Bearer ${jwt}` },
    });
    assertEquals(listRes.status, 200, `GET list status=${listRes.status}`);
    const listBody = await listRes.json();
    assert(
      Array.isArray(listBody.sessions) && listBody.sessions.some((s: { id: string }) => s.id === sessionId),
      "sesja nieobecna w historii",
    );

    // 4) GET /sessions/:id — szczegóły + raport.
    const getRes = await fetch(`${FN_BASE}/session-proxy/sessions/${sessionId}`, {
      headers: { Authorization: `Bearer ${jwt}` },
    });
    assertEquals(getRes.status, 200, `GET detail status=${getRes.status}`);
    const getBody = await getRes.json();
    assertEquals(getBody.session.id, sessionId);
    assert(getBody.report && Array.isArray(getBody.report.strengths), "brak raportu w szczegółach");
  } finally {
    // 5) DELETE /sessions/:id — kaskada; czystość zawsze (nawet po asercji błędu).
    const delRes = await fetch(`${FN_BASE}/session-proxy/sessions/${sessionId}`, {
      method: "DELETE",
      headers: { Authorization: `Bearer ${jwt}` },
    });
    assertEquals(delRes.status, 200, `DELETE status=${delRes.status}`);

    // 6) GET po DELETE → 404 (czystość potwierdzona).
    const afterRes = await fetch(`${FN_BASE}/session-proxy/sessions/${sessionId}`, {
      headers: { Authorization: `Bearer ${jwt}` },
    });
    assertEquals(afterRes.status, 404, `GET po DELETE status=${afterRes.status}`);
  }
});
