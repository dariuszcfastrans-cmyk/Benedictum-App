// Testy adapterów LLM (KROK 4) — czyste tłumacze (bez fetch).
// Parity z legacy proxy (gemini-proxy / openrouter-proxy, usunięte w KROKU 8) 1:1:
//  - payloady (struktura, temperature/maxOutputTokens z TaskSpec, BS-3 thinkingConfig:0,
//    reasoning:{enabled:false}, user),
//  - parsowanie (empty → reason "empty", raport niepoprawny → reason "invalid").
// Uruchom: deno test supabase/functions/_shared/adapters/adapters_test.ts

import { assertEquals, assertThrows } from "jsr:@std/assert";
import { createTaskSpec, type TaskSpec } from "../core/index.ts";
import { geminiAdapter } from "./gemini.ts";
import { openrouterAdapter } from "./openrouter.ts";

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(`ASSERT_FAILED: ${msg}`);
}

const reportTask: TaskSpec = createTaskSpec({
  kind: "report",
  scenario: "Negocjacje płacowe",
  context: "Kontekst zebrany przez Coacha",
  capabilities: ["text"],
  maxTokens: 800,
  temperature: 0.4,
  userId: "u-test-1",
});

const chatTask: TaskSpec = createTaskSpec({
  kind: "chat",
  scenario: "Negocjacje płacowe",
  message: "Chcę podbić stawkę o 20%",
  persona: "optimist",
  capabilities: ["text"],
  maxTokens: 300,
  temperature: 0.7,
  userId: "u-test-1",
});

const intakeTask: TaskSpec = createTaskSpec({
  kind: "chat",
  scenario: "Negocjacje",
  message: "Opowiedz o pracy",
  mode: "intake",
  capabilities: ["text"],
  maxTokens: 300,
  temperature: 0.7,
});

const validReportJson = JSON.stringify({
  strengths: ["Mocna argumentacja"],
  gaps: ["Brak danych o widełkach"],
  action_items: ["Przygotować widełki"],
  overall_rating: 4,
});

Deno.test("gemini: buildRequest report — parity payloadu", () => {
  const req = geminiAdapter.buildRequest(reportTask, "gemini-2.5-flash", { apiKey: "k1" });
  assertEquals(req.method, "POST");
  assertEquals(req.path, "/v1beta/models/gemini-2.5-flash:generateContent");
  assertEquals(req.query, { key: "k1" });
  assertEquals(req.headers, { "Content-Type": "application/json" });
  const body = req.body as {
    system_instruction: { parts: Array<{ text: string }> };
    contents: Array<{ role: string; parts: Array<{ text: string }> }>;
    generationConfig: { temperature: number; maxOutputTokens: number; thinkingConfig: { thinkingBudget: number } };
  };
  const sysText = body.system_instruction.parts[0].text;
  assert(!sysText.includes("{scenario}") && !sysText.includes("{context}"), "surowy placeholder w system prompt");
  assertEquals(body.contents[0].role, "user");
  assertEquals(body.contents[0].parts[0].text, "Wygeneruj raport końcowy sesji.");
  assertEquals(body.generationConfig, { temperature: 0.4, maxOutputTokens: 800, thinkingConfig: { thinkingBudget: 0 } });
});

Deno.test("gemini: buildRequest chat — persona analyze i intake→coach", () => {
  const analyze = geminiAdapter.buildRequest(chatTask, "gemini-2.5-flash", { apiKey: "k" });
  const sysAnalyze = (analyze.body as { system_instruction: { parts: Array<{ text: string }> } })
    .system_instruction.parts[0].text;
  assert(sysAnalyze.length > 0, "pusty system prompt");
  const intake = geminiAdapter.buildRequest(intakeTask, "gemini-2.5-flash", { apiKey: "k" });
  const sysIntake = (intake.body as { system_instruction: { parts: Array<{ text: string }> } })
    .system_instruction.parts[0].text;
  assert(sysIntake.length > 0, "pusty system prompt intake");
  // Wymagane: persona istnieje (analyze) i message niepusty.
  assertThrows(() => geminiAdapter.buildRequest({ ...chatTask, persona: "ghost" }, "m", { apiKey: "k" }), TypeError);
  assertThrows(() => geminiAdapter.buildRequest({ ...chatTask, message: "  " }, "m", { apiKey: "k" }), TypeError);
});

Deno.test("gemini: parseResponse — empty / invalid / ok", () => {
  const okBody = { candidates: [{ content: { parts: [{ text: validReportJson }] } }] };
  assertEquals(geminiAdapter.parseResponse(okBody, reportTask), {
    ok: true,
    value: { kind: "report", report: { strengths: ["Mocna argumentacja"], gaps: ["Brak danych o widełkach"], action_items: ["Przygotować widełki"], overall_rating: 4 } },
  });
  assertEquals(geminiAdapter.parseResponse({ candidates: [] }, reportTask), { ok: false, reason: "empty" });
  assertEquals(
    geminiAdapter.parseResponse({ candidates: [{ content: { parts: [{ text: "   " }] } }] }, reportTask),
    { ok: false, reason: "empty" },
  );
  assertEquals(
    geminiAdapter.parseResponse({ candidates: [{ content: { parts: [{ text: "to nie jest raport" }] } }] }, reportTask),
    { ok: false, reason: "invalid" },
  );
  assertEquals(
    geminiAdapter.parseResponse({ candidates: [{ content: { parts: [{ text: "cześć" }] } }] }, chatTask),
    { ok: true, value: { kind: "chat", text: "cześć" } },
  );
});

Deno.test("openrouter: buildRequest report — parity payloadu", () => {
  const req = openrouterAdapter.buildRequest(reportTask, "openrouter/free", { apiKey: "k2" });
  assertEquals(req.method, "POST");
  assertEquals(req.path, "/api/v1/chat/completions");
  assertEquals(req.query, {});
  assertEquals(req.headers.Authorization, "Bearer k2");
  const body = req.body as {
    model: string;
    messages: Array<{ role: string; content: string }>;
    temperature: number;
    max_tokens: number;
    reasoning: { enabled: boolean };
    user?: string;
  };
  assertEquals(body.model, "openrouter/free");
  assertEquals(body.temperature, 0.4);
  assertEquals(body.max_tokens, 800);
  assertEquals(body.reasoning, { enabled: false });
  assertEquals(body.user, "u-test-1");
  assertEquals(body.messages[0].role, "system");
  assertEquals(body.messages[1], { role: "user", content: "Wygeneruj raport końcowy sesji." });
});

Deno.test("openrouter: buildRequest chat — messages system+user", () => {
  const req = openrouterAdapter.buildRequest(chatTask, "openrouter/auto", { apiKey: "k" });
  const body = req.body as { messages: Array<{ role: string; content: string }> };
  assertEquals(body.messages[0].role, "system");
  assertEquals(body.messages[1], { role: "user", content: "Chcę podbić stawkę o 20%" });
  assertThrows(() => openrouterAdapter.buildRequest({ ...chatTask, message: "  " }, "m", { apiKey: "k" }), TypeError);
});

Deno.test("openrouter: parseResponse — string / tablica / empty / invalid", () => {
  assertEquals(
    openrouterAdapter.parseResponse({ choices: [{ message: { content: "tekst" } }] }, chatTask),
    { ok: true, value: { kind: "chat", text: "tekst" } },
  );
  assertEquals(
    openrouterAdapter.parseResponse(
      { choices: [{ message: { content: [{ type: "text", text: "A" }, { type: "text", text: "B" }] } }] },
      chatTask,
    ),
    { ok: true, value: { kind: "chat", text: "A\nB" } },
  );
  assertEquals(
    openrouterAdapter.parseResponse({ choices: [{ message: { content: "  " } }] }, chatTask),
    { ok: false, reason: "empty" },
  );
  assertEquals(
    openrouterAdapter.parseResponse({ choices: [{ message: { content: "to nie jest raport" } }] }, reportTask),
    { ok: false, reason: "invalid" },
  );
  assertEquals(
    openrouterAdapter.parseResponse({ choices: [{ message: { content: validReportJson } }] }, reportTask).ok,
    true,
  );
});

Deno.test("K5: baseUrl adapterów (stałe providerów, parity z proxy)", () => {
  assertEquals(geminiAdapter.baseUrl, "https://generativelanguage.googleapis.com");
  assertEquals(openrouterAdapter.baseUrl, "https://openrouter.ai");
});

Deno.test("K5: gemini mapError — parity z gemini-proxy", () => {
  const e = geminiAdapter.mapError(429, 17, { model: "m" });
  assertEquals(e.code, "RATE_LIMITED");
  assertEquals(e.retryAfterSeconds, 17);
  assertEquals(geminiAdapter.mapError(400, undefined, { model: "m" }).code, "QUOTA_EXHAUSTED");
  assertEquals(geminiAdapter.mapError(403, undefined, { model: "m" }).code, "QUOTA_EXHAUSTED");
  assertEquals(geminiAdapter.mapError(500, undefined, { model: "m" }).code, "UPSTREAM_ERROR");
  assertEquals(geminiAdapter.mapError(404, undefined, { model: "m" }).code, "UPSTREAM_ERROR");
});

Deno.test("K5: openrouter mapError — parity z openrouter-proxy", () => {
  const e = openrouterAdapter.mapError(429, 12, { model: "m1" });
  assertEquals(e.code, "RATE_LIMITED");
  assertEquals(e.retryAfterSeconds, 12);
  const blocked = openrouterAdapter.mapError(404, undefined, { model: "m2" });
  assertEquals(blocked.code, "MODEL_OR_POLICY_BLOCKED");
  assertEquals(blocked.providerDetail, "m2");
  for (const s of [400, 401, 402, 403]) {
    const q = openrouterAdapter.mapError(s, undefined, { model: "m3" });
    assertEquals(q.code, "QUOTA_EXHAUSTED");
    assertEquals(q.providerDetail, "m3");
  }
  assertEquals(openrouterAdapter.mapError(500, undefined, { model: "m4" }).code, "UPSTREAM_ERROR");
});