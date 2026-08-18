// Testy Core types v1.1 (KROK 3) — runtime + użycie typów (type-check pliku weryfikuje
// powierzchnię typów; moduł jest czysty — bez I/O i sieci).
// Uruchom: deno test supabase/functions/_shared/core/core_test.ts

import { assertEquals, assertThrows } from "jsr:@std/assert";
import {
  CanonicalError,
  createTaskSpec,
  imagePart,
  parseReport,
  textPart,
  validateExecutionTrack,
  type ExecutionTrack,
  type ReportContract,
  type TaskSpec,
} from "./index.ts";

// Użycie typów na poziomie kompilacji (deno test type-checkuje ten plik).
const task: TaskSpec = createTaskSpec({
  kind: "chat",
  scenario: "negocjacje płacowe",
  message: "Chcę podbić stawkę o 20%",
  capabilities: ["text"],
  maxTokens: 300,
  temperature: 0.7,
});

const validTrack: ExecutionTrack = {
  id: "track-gemini",
  name: "Gemini 2.5 Flash (produkcja)",
  description: "Główny track",
  provider: "gemini",
  carrier: { kind: "secret-json", secretName: "LLM_TRACK_GEMINI" },
  models: ["gemini-2.5-flash"],
  capabilities: ["text"],
  required: true,
};

Deno.test("core: textPart / imagePart — jawne parametry (zero silent defaults)", () => {
  assertEquals(textPart("A"), { kind: "text", text: "A" });
  assertThrows(() => textPart(""), TypeError);
  assertThrows(() => textPart("   "), TypeError);
  assertThrows(() => imagePart(""), TypeError);
});

Deno.test("core: createTaskSpec — walidacja wymaganych pól", () => {
  assertEquals(task.scenario, "negocjacje płacowe");
  assertThrows(() => createTaskSpec({ ...task, scenario: " " }), TypeError);
  assertThrows(() => createTaskSpec({ ...task, maxTokens: 0 }), TypeError);
  assertThrows(() => createTaskSpec({ ...task, temperature: 3 }), TypeError);
  assertThrows(() => createTaskSpec({ ...task, temperature: -0.1 }), TypeError);
  assertThrows(
    () => createTaskSpec({ ...task, kind: "chat", message: "  " }),
    TypeError,
  );
  // kind=report nie wymaga message.
  const reportTask: TaskSpec = createTaskSpec({
    kind: "report",
    scenario: "sesja",
    capabilities: ["text"],
    maxTokens: 800,
    temperature: 0.4,
  });
  assertEquals(reportTask.kind, "report");
});

Deno.test("core: createTaskSpec — mode i userId (KROK 4, J.5 additive)", () => {
  const m = createTaskSpec({
    ...task,
    mode: "intake",
    userId: "u-42",
  });
  assertEquals(m.mode, "intake");
  assertEquals(m.userId, "u-42");
  // mode bez podania = undefined (nie "analyze" na zapas — zero silent defaults).
  const plain = createTaskSpec({ ...task, mode: undefined });
  assertEquals(plain.mode, undefined);
  // Walidacja runtime (rzutowanie przez unknown: "oops" nie przechodzi type-checku intencji).
  assertThrows(
    () => createTaskSpec({ ...task, mode: "oops" } as unknown as TaskSpec),
    TypeError,
  );
});

Deno.test("core: CanonicalError — domyślne statusy i retry", () => {
  const rl = new CanonicalError({ code: "RATE_LIMITED", retryAfterSeconds: 30 });
  assertEquals(rl.status, 429);
  assertEquals(rl.retryAfterSeconds, 30);
  assertEquals(new CanonicalError({ code: "INVALID_REPORT" }).status, 422);
  assertEquals(new CanonicalError({ code: "EMPTY_RESPONSE" }).status, 422);
  assertEquals(new CanonicalError({ code: "NOT_CONFIGURED" }).status, 503);
  assertEquals(new CanonicalError({ code: "NO_MODELS" }).status, 503);
  // Jawny status ma pierwszeństwo.
  assertEquals(new CanonicalError({ code: "RATE_LIMITED", status: 500 }).status, 500);
  // Błąd jest sanitarny: wiadomość = kod, bez sekretów.
  assertEquals(rl.message, "RATE_LIMITED");
});

Deno.test("core: validateExecutionTrack — nośnik i niepuste listy", () => {
  assertEquals(validateExecutionTrack(validTrack), validTrack);
  assertThrows(() => validateExecutionTrack({ ...validTrack, models: [] }), TypeError);
  assertThrows(() => validateExecutionTrack({ ...validTrack, capabilities: [] }), TypeError);
  assertThrows(
    () => validateExecutionTrack({ ...validTrack, carrier: { kind: "database", table: "t", key: "k" } }),
    TypeError,
  );
  // D/17 (KROK 5): provider wymagany (engine mapuje track → adapter po provider).
  assertThrows(() => validateExecutionTrack({ ...validTrack, provider: " " }), TypeError);
  assertThrows(
    () => validateExecutionTrack({ ...validTrack, provider: "" }),
    TypeError,
  );
});

Deno.test("core: validateExecutionTrack — dataPolicy (KROK 6, aktywne deklaracje)", () => {
  const withPolicy = validateExecutionTrack({
    ...validTrack,
    dataPolicy: { region: "eu", training: false, retentionDays: 30 },
  });
  assertEquals(withPolicy.dataPolicy, { region: "eu", training: false, retentionDays: 30 });
  // dataPolicy bez pola = undefined (zero silent defaults — brak cichej deklaracji).
  assertEquals(validateExecutionTrack(validTrack).dataPolicy, undefined);
  // Niepoprawne kształty → TypeError (walidacja deklaracji).
  assertThrows(
    () => validateExecutionTrack({ ...validTrack, dataPolicy: { region: " " } }),
    TypeError,
  );
  assertThrows(
    () => validateExecutionTrack({ ...validTrack, dataPolicy: { training: "yes" } as unknown as { training?: boolean } }),
    TypeError,
  );
  assertThrows(
    () => validateExecutionTrack({ ...validTrack, dataPolicy: { retentionDays: 0 } }),
    TypeError,
  );
  assertThrows(
    () => validateExecutionTrack({ ...validTrack, dataPolicy: { retentionDays: -3 } }),
    TypeError,
  );
  assertThrows(
    () => validateExecutionTrack({ ...validTrack, dataPolicy: { retentionDays: 2.5 } }),
    TypeError,
  );
});

Deno.test("core: ReportContract — kanon w core, parseReport (core, KROK 4) zwraca dokładnie ten kształt", () => {
  const r: ReportContract | null = parseReport(
    JSON.stringify({ strengths: ["A"], gaps: ["B"], action_items: ["C"], overall_rating: 4 }),
  );
  assertEquals(r !== null, true);
  // Brak dryfu: walidator zwraca dokładnie klucze kontraktu core.
  assertEquals(Object.keys(r!).sort(), ["action_items", "gaps", "overall_rating", "strengths"]);
});

Deno.test("core: parseReport — pusta treść, ramki markdown, złe ratingi", () => {
  assertEquals(parseReport("   "), null);
  assertEquals(parseReport(""), null);
  const wrapped = "```json\n" + JSON.stringify({ strengths: ["A"], gaps: [], action_items: [], overall_rating: 5 }) + "\n```";
  assertEquals(parseReport(wrapped)?.overall_rating, 5);
  assertEquals(parseReport("not json"), null);
  assertEquals(parseReport(JSON.stringify({ strengths: [], gaps: [], action_items: [], overall_rating: 0 })), null);
  assertEquals(parseReport(JSON.stringify({ strengths: [], gaps: [], action_items: [], overall_rating: 6 })), null);
  assertEquals(parseReport(JSON.stringify({ strengths: "A", gaps: [], action_items: [], overall_rating: 3 })), null);
});