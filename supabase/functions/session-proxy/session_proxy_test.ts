// Testy Deno — automatyczna suite session-proxy (Fala 2A.2, rejestr ryzyka R4).
// Odtwarza wiersze 1-20 macierzy dowodowej §23 (Dyrektywa 02, CHECKPOINT_5).
// Wiersze 21-22 pokrywa osobno: prompts_test.ts (render promptu) i testy Flutter (ReportScreen).
//
// Wymagania uruchomienia:
//   - działający lokalny Supabase (supabase start)
//   - klucze lokalne (domyślnie wczytane z supabase status; można nadpisać przez env):
//       TEST_SUPABASE_URL            (domyślnie http://127.0.0.1:54321)
//       TEST_ANON_KEY                (domyślnie sb_publishable_...)
//       TEST_SERVICE_KEY             (domyślnie sb_secret_...)
//
// Uruchom: deno test --allow-net --allow-env supabase/functions/session-proxy/session_proxy_test.ts
//
// Uwaga (fakt z kodu, nie zmiana): sessions_user_id_fkey NIE ma ON DELETE CASCADE.
// DELETE usera z aktywnymi sesjami jest blokowany przez FK (23503) — macierz §23
// wiersz 15 zakładał kaskadę, rzeczywiste zachowanie różni się. Suite utrwala FAKT.

import { assertEquals, assert } from "jsr:@std/assert";

const SUPABASE_URL = Deno.env.get("TEST_SUPABASE_URL") ?? "http://127.0.0.1:54321";
const ANON_KEY = Deno.env.get("TEST_ANON_KEY") ?? "";
const SERVICE_KEY = Deno.env.get("TEST_SERVICE_KEY") ?? "";
const FN_BASE = `${SUPABASE_URL}/functions/v1/session-proxy`;

if (!ANON_KEY || !SERVICE_KEY) {
  throw new Error(
    "Brak kluczy lokalnych (TEST_ANON_KEY / TEST_SERVICE_KEY). Pobierz z: supabase status",
  );
}

const RT = Math.random().toString(36).slice(2, 8);

type User = { id: string; jwt: string };

async function signup(tag: string): Promise<User> {
  const res = await fetch(`${SUPABASE_URL}/auth/v1/signup`, {
    method: "POST",
    headers: {
      apikey: ANON_KEY,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      email: `${tag}_${RT}@suite.test`,
      password: "SuitePass123",
    }),
  });
  const body = await res.json();
  assert(res.ok, `signup failed: ${JSON.stringify(body)}`);
  return { id: body.user.id, jwt: body.access_token };
}

function fn(path: string, init?: RequestInit & { jwt?: string; apikey?: string }) {
  const headers: Record<string, string> = {
    apikey: init?.apikey ?? ANON_KEY,
    "Content-Type": "application/json",
  };
  if (init?.jwt) headers.Authorization = `Bearer ${init.jwt}`;
  return fetch(`${FN_BASE}${path}`, { ...init, headers });
}

const VALID_REPORT = {
  strengths: ["asertywne stawianie granic"],
  gaps: ["brak danych liczbowych"],
  action_items: ["przygotuj argument"],
  overall_rating: 4,
};

let userA!: User;
let userB!: User;

async function cleanup(user: User) {
  // Najpierw dane usera (kolejność ważna: FK sessions->auth.users bez CASCADE),
  // potem sam user przez Admin API.
  await fetch(`${SUPABASE_URL}/rest/v1/sessions?user_id=eq.${user.id}`, {
    method: "DELETE",
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
  });
  await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${user.id}`, {
    method: "DELETE",
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
  });
}

// ---- Setup wspólny: USER_A i USER_B (jak w macierzy §23) ----
Deno.test("setup: tworzy USER_A i USER_B", async () => {
  userA = await signup("a");
  userB = await signup("b");
  assert(userA.id && userB.id, "brak id użytkowników");
  assert(userA.jwt && userB.jwt, "brak JWT użytkowników");
});

// ---- Wiersz 1: Session tworzona z poprawnym JWT ----
Deno.test("w1: POST /sessions z JWT USER_A -> 201, sesja w DB", async () => {
  const res = await fn("/sessions", {
    method: "POST",
    jwt: userA.jwt,
    body: JSON.stringify({
      scenario_key: "scenario_wywiad",
      title: "Test 1",
      user_statements: ["Chcę 20% podwyżki"],
      report: VALID_REPORT,
    }),
  });
  const resText = await res.text();
  assertEquals(res.status, 201, resText);
  const body = JSON.parse(resText);
  assert(body.ok === true && body.session_id, "brak session_id w odpowiedzi");
});

// ---- Wiersz 2: Session bez JWT -> 401 (Gate 0) ----
Deno.test("w2: POST bez JWT -> 401", async () => {
  const res = await fn("/sessions", {
    method: "POST",
    body: JSON.stringify({ scenario_key: "x", user_statements: [], report: VALID_REPORT }),
  });
  assertEquals(res.status, 401);
});

// ---- Wiersz 3: Session ze sfałszowanym JWT -> 401 ----
Deno.test("w3: POST ze sfałszowanym JWT -> 401", async () => {
  const res = await fn("/sessions", {
    method: "POST",
    jwt: "eyJhbGciOiJIUzI1NiJ9.fake.fake",
    body: JSON.stringify({ scenario_key: "x", user_statements: [], report: VALID_REPORT }),
  });
  assertEquals(res.status, 401);
});

// ---- Wiersze 4-8, 12: cykl życiowy sesji (własna/cudza/nieistniejąca/DELETE) ----
Deno.test("w4+w12: GET /sessions/:id własnej -> 200 + pełny kontrakt raportu", async () => {
  const created = await fn("/sessions", {
    method: "POST",
    jwt: userA.jwt,
    body: JSON.stringify({
      scenario_key: "scenario_wywiad",
      title: "Round-trip",
      user_statements: ["statement A", "statement B"],
      report: VALID_REPORT,
    }),
  });
  assertEquals(created.status, 201);
  const { session_id } = await created.json();

  const got = await fn(`/sessions/${session_id}`, { jwt: userA.jwt });
  assertEquals(got.status, 200);
  const payload = await got.json();
  assert(payload.session?.id === session_id, "session.id niezgodny");
  assert(payload.session?.user_id === undefined, "nie powinno ujawniać user_id w payload?");
  assertEquals(payload.report.strengths, VALID_REPORT.strengths);
  assertEquals(payload.report.gaps, VALID_REPORT.gaps);
  assertEquals(payload.report.action_items, VALID_REPORT.action_items);
  assertEquals(payload.report.overall_rating, VALID_REPORT.overall_rating);
});

Deno.test("w5: GET /sessions/:id cudzej (USER_B o sesji USER_A) -> 404", async () => {
  const created = await fn("/sessions", {
    method: "POST",
    jwt: userA.jwt,
    body: JSON.stringify({
      scenario_key: "scenario_wywiad",
      user_statements: ["x"],
      report: VALID_REPORT,
    }),
  });
  const { session_id } = await created.json();
  const got = await fn(`/sessions/${session_id}`, { jwt: userB.jwt });
  assertEquals(got.status, 404);
});

Deno.test("w6: GET /sessions/:id nieistniejącej -> 404 (jak cudza)", async () => {
  const got = await fn("/sessions/00000000-0000-0000-0000-000000000000", { jwt: userA.jwt });
  assertEquals(got.status, 404);
});

Deno.test("w7: DELETE /sessions/:id własnej -> 200, potem GET -> 404", async () => {
  const created = await fn("/sessions", {
    method: "POST",
    jwt: userA.jwt,
    body: JSON.stringify({
      scenario_key: "scenario_wywiad",
      user_statements: ["x"],
      report: VALID_REPORT,
    }),
  });
  const { session_id } = await created.json();
  const del = await fn(`/sessions/${session_id}`, { method: "DELETE", jwt: userA.jwt });
  assertEquals(del.status, 200);
  const gone = await fn(`/sessions/${session_id}`, { jwt: userA.jwt });
  assertEquals(gone.status, 404);
});

Deno.test("w8: DELETE /sessions/:id cudzej (USER_B o sesji USER_A) -> 404", async () => {
  const created = await fn("/sessions", {
    method: "POST",
    jwt: userA.jwt,
    body: JSON.stringify({
      scenario_key: "scenario_wywiad",
      user_statements: ["x"],
      report: VALID_REPORT,
    }),
  });
  const { session_id } = await created.json();
  const del = await fn(`/sessions/${session_id}`, { method: "DELETE", jwt: userB.jwt });
  assertEquals(del.status, 404);
});

// ---- Wiersz 9: user_id w body -> 422 ----
Deno.test("w9: POST z user_id w body -> 422 USER_ID_FORBIDDEN", async () => {
  const res = await fn("/sessions", {
    method: "POST",
    jwt: userA.jwt,
    body: JSON.stringify({
      user_id: userA.id,
      scenario_key: "scenario_wywiad",
      user_statements: ["x"],
      report: VALID_REPORT,
    }),
  });
  assertEquals(res.status, 422);
  assertEquals((await res.json()).error, "USER_ID_FORBIDDEN");
});

// ---- Wiersz 10: session_id w body -> 422 ----
Deno.test("w10: POST z session_id w body -> 422 USER_ID_FORBIDDEN", async () => {
  const res = await fn("/sessions", {
    method: "POST",
    jwt: userA.jwt,
    body: JSON.stringify({
      session_id: "00000000-0000-0000-0000-000000000000",
      scenario_key: "scenario_wywiad",
      user_statements: ["x"],
      report: VALID_REPORT,
    }),
  });
  assertEquals(res.status, 422);
  assertEquals((await res.json()).error, "USER_ID_FORBIDDEN");
});

// ---- Wiersz 11: overall_rating: 0 -> 422 INVALID_REPORT (przed INSERT) ----
Deno.test("w11: POST z overall_rating 0 -> 422 INVALID_REPORT", async () => {
  const res = await fn("/sessions", {
    method: "POST",
    jwt: userA.jwt,
    body: JSON.stringify({
      scenario_key: "scenario_wywiad",
      user_statements: ["x"],
      report: { ...VALID_REPORT, overall_rating: 0 },
    }),
  });
  assertEquals(res.status, 422);
  assertEquals((await res.json()).error, "INVALID_REPORT");
});

// ---- Wiersz 13: Retencja — sesja starsza niż 90 dni wykluczona ----
// Wiersz tworzony bezpośrednio w DB (created_at w przeszłości) — funkcja nie pozwala ustawić created_at.
Deno.test("w13: retencja — sesja 120 dni wstecz wykluczona z historii i GET -> 404", async () => {
  const old = new Date(Date.now() - 120 * 24 * 60 * 60 * 1000).toISOString();
  const ins = await fetch(`${SUPABASE_URL}/rest/v1/sessions`, {
    method: "POST",
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "return=representation",
    },
    body: JSON.stringify({
      user_id: userA.id,
      scenario_key: "scenario_stary",
      title: "stary",
      status: "completed",
      created_at: old,
      completed_at: old,
    }),
  });
  const row = (await ins.json())[0];
  const oldId = row.id as string;

  const hist = await fn("/sessions", { jwt: userA.jwt });
  const histBody = await hist.json();
  const ids = (histBody.sessions as { id: string }[]).map((s) => s.id);
  assert(!ids.includes(oldId), "stara sesja nie powinna być w historii");

  const got = await fn(`/sessions/${oldId}`, { jwt: userA.jwt });
  assertEquals(got.status, 404);
});

// ---- Wiersz 14: Retencja — sesja w granicach 90 dni widoczna ----
Deno.test("w14: retencja — świeża sesja widoczna w historii i GET -> 200", async () => {
  const created = await fn("/sessions", {
    method: "POST",
    jwt: userA.jwt,
    body: JSON.stringify({
      scenario_key: "scenario_wywiad",
      title: "świeża",
      user_statements: ["x"],
      report: VALID_REPORT,
    }),
  });
  assertEquals(created.status, 201);
  const { session_id } = await created.json();

  const hist = await fn("/sessions", { jwt: userA.jwt });
  const histBody = await hist.json();
  const ids = (histBody.sessions as { id: string }[]).map((s) => s.id);
  assert(ids.includes(session_id), "świeża sesja powinna być w historii");

  const got = await fn(`/sessions/${session_id}`, { jwt: userA.jwt });
  assertEquals(got.status, 200);
});

// ---- Wiersz 15: Kaskada — fakt z kodu (FK bez CASCADE) ----
Deno.test("w15: FAKT — DELETE usera z aktywną sesją jest blokowany przez FK (23503)", async () => {
  const temp = await signup("w15");
  const created = await fn("/sessions", {
    method: "POST",
    jwt: temp.jwt,
    body: JSON.stringify({
      scenario_key: "scenario_wywiad",
      user_statements: ["x"],
      report: VALID_REPORT,
    }),
  });
  assertEquals(created.status, 201);

  const del = await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${temp.id}`, {
    method: "DELETE",
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
  });
  // Fakt: FK sessions_user_id_fkey bez ON DELETE CASCADE (migracja 01) -> blokada.
  assertEquals(del.status, 500);
  const body = await del.json();
  assert(body.code === "23503", `oczekiwano FK violation 23503, otrzymano: ${JSON.stringify(body)}`);

  // Porządek: najpierw sesje, potem usera.
  await cleanup(temp);
});

// ---- Wiersz 16: Historia własna — najnowsze-pierwsze ----
Deno.test("w16: GET /sessions — historia własna, najnowsze-pierwsze", async () => {
  const a = await fn("/sessions", {
    method: "POST",
    jwt: userA.jwt,
    body: JSON.stringify({ scenario_key: "s1", user_statements: ["a"], report: VALID_REPORT }),
  });
  const { session_id: first } = await a.json();
  const b = await fn("/sessions", {
    method: "POST",
    jwt: userA.jwt,
    body: JSON.stringify({ scenario_key: "s2", user_statements: ["b"], report: VALID_REPORT }),
  });
  const { session_id: second } = await b.json();

  const hist = await fn("/sessions", { jwt: userA.jwt });
  const ids = ((await hist.json()).sessions as { id: string }[]).map((s) => s.id);
  assert(ids.indexOf(second) < ids.indexOf(first), "najnowsza sesja powinna być pierwsza");
});

// ---- Wiersz 17: Historia cudza — nie zawiera sesji innego usera ----
Deno.test("w17: GET /sessions — historia USER_B nie zawiera sesji USER_A", async () => {
  const created = await fn("/sessions", {
    method: "POST",
    jwt: userA.jwt,
    body: JSON.stringify({ scenario_key: "tylkoA", user_statements: ["x"], report: VALID_REPORT }),
  });
  const { session_id } = await created.json();

  const hist = await fn("/sessions", { jwt: userB.jwt });
  const ids = ((await hist.json()).sessions as { id: string }[]).map((s) => s.id);
  assert(!ids.includes(session_id), "historia B nie powinna zawierać sesji A");
});

// ---- Wiersz 18: RLS anon -> DENY ----
Deno.test("w18: RLS — anon nie ma dostępu do sessions (42501)", async () => {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/sessions?select=id`, {
    headers: { apikey: ANON_KEY, Authorization: `Bearer ${ANON_KEY}` },
  });
  assert(res.status === 401 || res.status === 403, `oczekiwano DENY, otrzymano ${res.status}`);
});

// ---- Wiersz 19: RLS authenticated CRUD własnych ----
Deno.test("w19: RLS — authenticated ma pełny CRUD własnych sesji", async () => {
  const headers = {
    apikey: ANON_KEY,
    Authorization: `Bearer ${userA.jwt}`,
    "Content-Type": "application/json",
    Prefer: "return=representation",
  };
  // INSERT własnej
  const ins = await fetch(`${SUPABASE_URL}/rest/v1/sessions`, {
    method: "POST",
    headers,
    body: JSON.stringify({ user_id: userA.id, scenario_key: "rls_crud", status: "active" }),
  });
  assert([200, 201].includes(ins.status), `INSERT authenticated: ${ins.status}`);
  const row = (await ins.json())[0];

  // SELECT własnej
  const sel = await fetch(`${SUPABASE_URL}/rest/v1/sessions?select=id&id=eq.${row.id}`, {
    headers,
  });
  assertEquals(sel.status, 200);

  // UPDATE własnej
  const upd = await fetch(`${SUPABASE_URL}/rest/v1/sessions?id=eq.${row.id}`, {
    method: "PATCH",
    headers,
    body: JSON.stringify({ status: "completed" }),
  });
  assert([200, 204].includes(upd.status), `UPDATE authenticated: ${upd.status}`);

  // DELETE własnej
  const del = await fetch(`${SUPABASE_URL}/rest/v1/sessions?id=eq.${row.id}`, {
    method: "DELETE",
    headers,
  });
  assert([200, 204].includes(del.status), `DELETE authenticated: ${del.status}`);
});

// ---- Wiersz 20: service_role — SELECT/INSERT/DELETE (bez UPDATE) ----
Deno.test("w20: service_role — SELECT/INSERT/DELETE OK, UPDATE DENIED (42501)", async () => {
  const headers = {
    apikey: SERVICE_KEY,
    Authorization: `Bearer ${SERVICE_KEY}`,
    "Content-Type": "application/json",
    Prefer: "return=representation",
  };
  const ins = await fetch(`${SUPABASE_URL}/rest/v1/sessions`, {
    method: "POST",
    headers,
    body: JSON.stringify({ user_id: userA.id, scenario_key: "sr", status: "active" }),
  });
  assert([200, 201].includes(ins.status), `INSERT service_role: ${ins.status}`);
  const row = (await ins.json())[0];

  const sel = await fetch(`${SUPABASE_URL}/rest/v1/sessions?select=id&id=eq.${row.id}`, {
    headers,
  });
  assertEquals(sel.status, 200);

  // UPDATE: brak GRANT UPDATE dla service_role (migracja ...03) -> 42501.
  const upd = await fetch(`${SUPABASE_URL}/rest/v1/sessions?id=eq.${row.id}`, {
    method: "PATCH",
    headers,
    body: JSON.stringify({ status: "completed" }),
  });
  assert(upd.status === 401 || upd.status === 403 || upd.status === 500, `UPDATE service_role: ${upd.status}`);

  const del = await fetch(`${SUPABASE_URL}/rest/v1/sessions?id=eq.${row.id}`, {
    method: "DELETE",
    headers,
  });
  assert([200, 204].includes(del.status), `DELETE service_role: ${del.status}`);
});

// ---- Czyszczenie ----
Deno.test("teardown: usuwa USER_A i USER_B oraz dane", async () => {
  await cleanup(userA);
  await cleanup(userB);
});
