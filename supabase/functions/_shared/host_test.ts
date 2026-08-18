// Testy jednostkowe wspólnych modułów hosta (KROK 7).
// Uruchom: deno test --allow-read --allow-env supabase/functions/_shared/host_test.ts
import { assertEquals } from "jsr:@std/assert";
import {
  ApiUpstreamError,
  corsResponse,
  decodeJwtUserId,
  json,
  safeErrorMessage,
  validateBody,
} from "./host.ts";

function expectApiError(fn: () => void, code: string): void {
  try {
    fn();
  } catch (e) {
    if (e instanceof ApiUpstreamError && e.code === code && e.status === 422) return;
    throw new Error(`oczekiwano ApiUpstreamError(${code},422), było: ${e}`);
  }
  throw new Error(`brak wyjątku: ${code}`);
}

Deno.test("host: validateBody — niepoprawne body (422)", () => {
  expectApiError(() => validateBody(null), "INVALID_JSON");
  expectApiError(() => validateBody("x"), "INVALID_JSON");
  expectApiError(() => validateBody({}), "MISSING_MESSAGE");
  expectApiError(() => validateBody({ message: "x" }), "MISSING_SCENARIO");
  expectApiError(() => validateBody({ mode: "report", scenario: "S" }), "MISSING_CONTEXT");
  expectApiError(() => validateBody({ mode: "report", context: "C" }), "MISSING_SCENARIO");
  expectApiError(() => validateBody({ message: "x", scenario: "S", persona: "nieznana" }), "INVALID_PERSONA");
  expectApiError(() => validateBody({ message: "x", scenario: "S", mode: "bad" }), "INVALID_MODE");
});

Deno.test("host: validateBody — poprawne body (chat)", () => {
  const chat = validateBody({ message: "  Cześć  ", scenario: "  Test  " });
  if (chat.mode !== "analyze") throw new Error(`mode=${chat.mode}`);
  if (chat.message !== "Cześć") throw new Error(`message=${chat.message}`);
  if (chat.scenario !== "Test") throw new Error(`scenario=${chat.scenario}`);
  if (chat.persona !== undefined) throw new Error("persona powinna być undefined");
});

Deno.test("host: validateBody — poprawne body (intake + persona + context)", () => {
  const intake = validateBody({
    message: "x", scenario: "S", persona: "coach", mode: "intake", context: "  kontekst  ",
  });
  if (intake.mode !== "intake") throw new Error(`mode=${intake.mode}`);
  if (intake.persona !== "coach") throw new Error(`persona=${intake.persona}`);
  if (intake.context !== "kontekst") throw new Error(`context=${intake.context}`);
});

Deno.test("host: validateBody — poprawne body (report, trim)", () => {
  const report = validateBody({ mode: "report", scenario: "  S  ", context: "  C  " });
  if (report.mode !== "report") throw new Error(`mode=${report.mode}`);
  if (report.scenario !== "S" || report.context !== "C") throw new Error("brak trimu");
});

Deno.test("host: decodeJwtUserId — tokeny", () => {
  const token = (payload: unknown) =>
    `${btoa(JSON.stringify({ alg: "none" }))}.${btoa(JSON.stringify(payload))}.x`;
  assertEquals(decodeJwtUserId(`Bearer ${token({ sub: "u-1" })}`), "u-1");
  assertEquals(decodeJwtUserId("Bearer bez-kropki"), null);
  assertEquals(decodeJwtUserId("Basic abc"), null);
  assertEquals(decodeJwtUserId(`Bearer ${token({})}`), null);
  assertEquals(decodeJwtUserId(""), null);
});

Deno.test("host: safeErrorMessage — redakcja i cięcie", () => {
  const key = "AIza" + "B".repeat(35);
  const sanitized = safeErrorMessage(new Error(`zawiera ${key} i sk-${"c".repeat(30)}`));
  if (!sanitized.includes("[REDACTED]")) throw new Error("brak redakcji kluczy");
  // Prawdziwy JWT: segmenty base64url (bez paddinguu `=`).
  const b64url = (s: string) => btoa(s).replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
  const jwt = `${b64url(JSON.stringify({ alg: "none" }))}.${b64url(JSON.stringify({ a: 1 }))}.sig`;
  if (!safeErrorMessage(jwt).includes("[REDACTED]")) throw new Error("brak redakcji JWT");
  const long = safeErrorMessage("a".repeat(500));
  if (long.length > 203) throw new Error("brak cięcia >200");
});

Deno.test("host: corsResponse i json — kształt odpowiedzi", async () => {
  const cors = corsResponse();
  if (!cors["Access-Control-Allow-Origin"]) throw new Error("brak CORS origin");
  const res = json({ ok: true }, 200);
  assertEquals(res.status, 200);
  if (!res.headers.get("Content-Type")?.includes("application/json")) {
    throw new Error("brak Content-Type json");
  }
  const body = await res.json();
  if (body.ok !== true) throw new Error("niepoprawne ciało json()");
});