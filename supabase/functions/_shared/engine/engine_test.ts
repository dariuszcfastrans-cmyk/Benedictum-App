// Testy engine (KROK 5) — transport + C-0 fallback + registry + router.
// Engine dostaje stub transportu (bez sieci); parity z proxy: EMPTY/INVALID → next model,
// 429/404/400 → mapError adaptera; ostatni błąd wygrywa; brak konfiguracji → NOT_CONFIGURED.
// Uruchom: deno test supabase/functions/_shared/engine/engine_test.ts

import { assertEquals, assertThrows } from "jsr:@std/assert";
import {
  CanonicalError,
  createTaskSpec,
  type ExecutionTrack,
  type TaskSpec,
} from "../core/index.ts";
import { geminiAdapter } from "../adapters/gemini.ts";
import { openrouterAdapter } from "../adapters/openrouter.ts";
import { Engine, type IExecutionEngine, type Transport } from "./engine.ts";
import { CapabilityPolicy, DataPolicy } from "./policies.ts";
import { StaticOrderRouter } from "./router.ts";
import { parseTracks, resolveCarrierKey } from "./registry.ts";
import type { TrackPolicy } from "../core/index.ts";

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(`ASSERT_FAILED: ${msg}`);
}

const reportTask: TaskSpec = createTaskSpec({
  kind: "report",
  scenario: "Negocjacje",
  context: "Kontekst",
  capabilities: ["text"],
  maxTokens: 800,
  temperature: 0.4,
  userId: "u-1",
});

const chatTask: TaskSpec = createTaskSpec({
  kind: "chat",
  scenario: "Negocjacje",
  message: "Podbij stawkę",
  persona: "optimist",
  capabilities: ["text"],
  maxTokens: 300,
  temperature: 0.7,
});

const visionTask: TaskSpec = createTaskSpec({
  kind: "chat",
  scenario: "Negocjacje",
  message: "Spójrz na obrazek",
  capabilities: ["vision"],
  maxTokens: 300,
  temperature: 0.7,
});

const geminiTrack: ExecutionTrack = {
  id: "t-gemini",
  name: "Gemini",
  description: "prod",
  provider: "gemini",
  carrier: { kind: "secret-json", secretName: "SECRET_GEMINI" },
  models: ["gemini-2.5-flash"],
  capabilities: ["text"],
  required: true,
};

const openrouterTrack: ExecutionTrack = {
  id: "t-or",
  name: "OpenRouter",
  description: "fallback",
  provider: "openrouter",
  carrier: { kind: "secret-json", secretName: "SECRET_OR" },
  models: ["openrouter/free", "openrouter/plus"],
  capabilities: ["text"],
  required: false,
};

function envWith(secrets: Record<string, string>): { getSecret(name: string): string | undefined } {
  return { getSecret: (name) => secrets[name] };
}

const secretGemini = JSON.stringify({ apiKey: "gk" });
const secretOr = JSON.stringify({ apiKey: "ok" });

const adapters = { gemini: geminiAdapter, openrouter: openrouterAdapter };

/// Stub transportu: sekwencja przypadków per wywołanie; kształt body wg baseUrl (parity).
type StubCase = "empty" | "invalid" | "valid" | "rate" | "blocked" | "quota" | "up";
function makeTransport(sequence: StubCase[], calls: Array<{ model: string; baseUrl: string; path: string }>): Transport {
  let i = 0;
  return async (req, baseUrl) => {
    const body = req.body as Record<string, unknown> | null;
    const model = typeof body?.model === "string"
      ? body.model
      : (req.path.split("/models/")[1]?.split(":")[0] ?? req.path);
    calls.push({ model, baseUrl, path: req.path });
    const c = sequence[i++] ?? "valid";
    const isGemini = baseUrl.includes("generativelanguage");
    const contentFor = (text: string) =>
      isGemini
        ? JSON.stringify({ candidates: [{ content: { parts: [{ text }] } }] })
        : JSON.stringify({ choices: [{ message: { content: text } }] });
    const validText = JSON.stringify({
      strengths: ["A"],
      gaps: ["B"],
      action_items: ["C"],
      overall_rating: 4,
    });
    switch (c) {
      case "empty":
        return new Response(contentFor("   "), { status: 200, headers: { "Content-Type": "application/json" } });
      case "invalid":
        return new Response(contentFor("to nie jest raport"), { status: 200, headers: { "Content-Type": "application/json" } });
      case "valid":
        return new Response(contentFor(validText), { status: 200, headers: { "Content-Type": "application/json" } });
      case "rate":
        return new Response("", { status: 429, headers: { "Retry-After": "17" } });
      case "blocked":
        return new Response("", { status: 404 });
      case "quota":
        return new Response("", { status: 400 });
      case "up":
        return new Response("", { status: 500 });
    }
  };
}

async function expectCanonical(fn: () => Promise<unknown>): Promise<CanonicalError> {
  let caught: unknown;
  try {
    await fn();
  } catch (e) {
    caught = e;
  }
  assert(caught instanceof CanonicalError, `oczekiwano CanonicalError, było: ${caught}`);
  return caught as CanonicalError;
}

Deno.test("StaticOrderRouter: kolejność i zawartość z tracka (kopia)", () => {
  const r = new StaticOrderRouter();
  const selected = r.select(openrouterTrack, reportTask);
  assertEquals(selected, ["openrouter/free", "openrouter/plus"]);
  assert(selected !== openrouterTrack.models, "router musi zwracać kopię");
  selected.push("x");
  assertEquals(openrouterTrack.models.length, 2);
});

Deno.test("registry: parseTracks — poprawna tablica / pusta / TypeError", () => {
  const tracks = parseTracks(JSON.stringify([
    { ...geminiTrack },
    { ...openrouterTrack },
  ]));
  assertEquals(tracks.length, 2);
  assertEquals(parseTracks(""), []);
  assertEquals(parseTracks("   \n "), []);
  assertThrows(() => parseTracks("nie json"), TypeError);
  assertThrows(() => parseTracks(JSON.stringify({ not: "array" })), TypeError);
  assertThrows(() => parseTracks(JSON.stringify([{ ...geminiTrack, provider: " " }])), TypeError);
});

Deno.test("registry: resolveCarrierKey — apiKey jawny / TypeError", () => {
  assertEquals(resolveCarrierKey(JSON.stringify({ apiKey: "k1" })), "k1");
  assertThrows(() => resolveCarrierKey(JSON.stringify({})), TypeError);
  assertThrows(() => resolveCarrierKey(JSON.stringify({ apiKey: " " })), TypeError);
  assertThrows(() => resolveCarrierKey("nie json"), TypeError);
  assertThrows(() => resolveCarrierKey("null"), TypeError);
});

Deno.test("engine: C-0 report — empty → invalid → valid (3 wywołania, parity z proxy)", async () => {
  const calls: Array<{ model: string; baseUrl: string; path: string }> = [];
  const engine = new Engine({
    adapters,
    transport: makeTransport(["empty", "invalid", "valid"], calls),
  });
  const track = { ...openrouterTrack, models: ["m-empty", "m-invalid", "m-valid"] };
  const result = await engine.execute(reportTask, [track], envWith({ SECRET_OR: secretOr }));
  if (result.kind !== "report") throw new Error("oczekiwano raportu");
  assertEquals(result.report.overall_rating, 4);
  assertEquals(calls.length, 3);
  assertEquals(calls[0].model, "m-empty");
  assertEquals(calls[1].model, "m-invalid");
  assertEquals(calls[2].model, "m-valid");
});

Deno.test("engine: chat zwraca tekst (openrouter), baseUrl użyty w transporcie", async () => {
  const calls: Array<{ model: string; baseUrl: string; path: string }> = [];
  const engine = new Engine({
    adapters,
    transport: makeTransport(["valid"], calls),
  });
  const result = await engine.execute(chatTask, [openrouterTrack], envWith({ SECRET_OR: secretOr }));
  if (result.kind !== "chat") throw new Error("oczekiwano tekstu");
  assertEquals(result.text.length > 0, true);
  assertEquals(calls[0].baseUrl, "https://openrouter.ai");
  assertEquals(calls[0].path, "/api/v1/chat/completions");
});

Deno.test("engine: gemini track — baseUrl i path parity (payload gemini)", async () => {
  const calls: Array<{ model: string; baseUrl: string; path: string }> = [];
  const engine = new Engine({
    adapters,
    transport: makeTransport(["valid"], calls),
  });
  const result = await engine.execute(reportTask, [geminiTrack], envWith({ SECRET_GEMINI: secretGemini }));
  if (result.kind !== "report") throw new Error("oczekiwano raportu");
  assertEquals(calls[0].baseUrl, "https://generativelanguage.googleapis.com");
  assertEquals(calls[0].path, "/v1beta/models/gemini-2.5-flash:generateContent");
});

Deno.test("engine: 429 wyczerpany → RATE_LIMITED z Retry-After (ostatni błąd wygrywa)", async () => {
  const engine = new Engine({ adapters, transport: makeTransport(["rate", "rate"], []) });
  const err = await expectCanonical(() =>
    engine.execute(reportTask, [openrouterTrack], envWith({ SECRET_OR: secretOr }))
  );
  assertEquals(err.code, "RATE_LIMITED");
  assertEquals(err.retryAfterSeconds, 17);
});

Deno.test("engine: 404 (gemini) → UPSTREAM_ERROR — parity mapError per provider", async () => {
  const engine = new Engine({ adapters, transport: makeTransport(["blocked"], []) });
  const err = await expectCanonical(() =>
    engine.execute(reportTask, [{ ...geminiTrack, models: ["m404"] }], envWith({ SECRET_GEMINI: secretGemini }))
  );
  // gemini: 404 → UPSTREAM_ERROR; openrouter: 404 → MODEL_OR_POLICY_BLOCKED (parity per provider,
  // zweryfikowane w adapters_test mapError).
  assertEquals(err.code, "UPSTREAM_ERROR");
});

Deno.test("engine: 400 → QUOTA_EXHAUSTED (openrouter)", async () => {
  const engine = new Engine({ adapters, transport: makeTransport(["quota"], []) });
  const err = await expectCanonical(() =>
    engine.execute(reportTask, [{ ...openrouterTrack, models: ["m400"] }], envWith({ SECRET_OR: secretOr }))
  );
  assertEquals(err.code, "QUOTA_EXHAUSTED");
});

Deno.test("engine: brak tracków → NOT_CONFIGURED (zero silent defaults)", async () => {
  const engine = new Engine({ adapters, transport: makeTransport(["valid"], []) });
  const err = await expectCanonical(() => engine.execute(reportTask, [], envWith({})));
  assertEquals(err.code, "NOT_CONFIGURED");
});

Deno.test("engine: brak dopasowania zdolności → NOT_CONFIGURED", async () => {
  const engine = new Engine({ adapters, transport: makeTransport(["valid"], []) });
  const err = await expectCanonical(() =>
    engine.execute(visionTask, [geminiTrack], envWith({ SECRET_GEMINI: secretGemini }))
  );
  assertEquals(err.code, "NOT_CONFIGURED");
});

Deno.test("engine: brak sekretu tracka → NOT_CONFIGURED (fail-fast, parity z proxy)", async () => {
  const engine = new Engine({ adapters, transport: makeTransport(["valid"], []) });
  const err = await expectCanonical(() =>
    engine.execute(reportTask, [geminiTrack], envWith({}))
  );
  assertEquals(err.code, "NOT_CONFIGURED");
});

Deno.test("engine: nieznany provider (brak adaptera) → NOT_CONFIGURED", async () => {
  const engine = new Engine({ adapters, transport: makeTransport(["valid"], []) });
  const track = { ...geminiTrack, provider: "unknown" };
  const err = await expectCanonical(() =>
    engine.execute(reportTask, [track], envWith({ SECRET_GEMINI: secretGemini }))
  );
  assertEquals(err.code, "NOT_CONFIGURED");
  assertEquals(err.providerDetail, "adapter:unknown");
});

Deno.test("engine: required pierwsze (kolejność tracków), sukces na pierwszym", async () => {
  const calls: Array<{ model: string; baseUrl: string; path: string }> = [];
  const engine = new Engine({
    adapters,
    transport: makeTransport(["valid"], calls),
  });
  const trackA = { ...geminiTrack, required: false };
  const trackB = { ...openrouterTrack, required: true, models: ["b1"] };
  const result = await engine.execute(reportTask, [trackA, trackB], envWith({
    SECRET_GEMINI: secretGemini,
    SECRET_OR: secretOr,
  }));
  if (result.kind !== "report") throw new Error("oczekiwano raportu");
  assertEquals(calls[0].model, "b1");
});

// ===== KROK 6 — polityki, R3, budżet, timeout =====

Deno.test("engine (K6): IExecutionEngine — Engine spełnia kontrakt (type-check)", () => {
  const engine: IExecutionEngine = new Engine({ adapters });
  assert(engine instanceof Engine, "Engine musi implementować IExecutionEngine");
});

Deno.test("engine (K6): CapabilityPolicy (domyślny łańcuch) — brak zdolności → NOT_CONFIGURED + reason", async () => {
  const engine = new Engine({ adapters, transport: makeTransport(["valid"], []) });
  const err = await expectCanonical(() =>
    engine.execute(visionTask, [geminiTrack], envWith({ SECRET_GEMINI: secretGemini }))
  );
  assertEquals(err.code, "NOT_CONFIGURED");
  assertEquals(err.providerDetail, "capability:requires:vision");
});

class BlockAllPolicy implements TrackPolicy {
  readonly id = "block";
  qualify() {
    return { ok: false, reason: "denied" };
  }
}

Deno.test("engine (K6): wymienny łańcuch polityk — własna polityka odrzuca bez zmian w engine", async () => {
  const engine = new Engine({
    adapters,
    transport: makeTransport(["valid"], []),
    policies: [new BlockAllPolicy()],
  });
  const err = await expectCanonical(() =>
    engine.execute(reportTask, [openrouterTrack], envWith({ SECRET_OR: secretOr }))
  );
  assertEquals(err.code, "NOT_CONFIGURED");
  assertEquals(err.providerDetail, "block:denied");
});

Deno.test("engine (K6): DataPolicy w łańcuchu (pusta egzekucja) + track z deklaracją — wykonanie OK", async () => {
  const calls: Array<{ model: string; baseUrl: string; path: string }> = [];
  const track = {
    ...openrouterTrack,
    dataPolicy: { region: "eu", training: false, retentionDays: 30 },
  };
  const engine = new Engine({
    adapters,
    transport: makeTransport(["valid"], calls),
    policies: [new CapabilityPolicy(), new DataPolicy()],
  });
  const result = await engine.execute(reportTask, [track], envWith({ SECRET_OR: secretOr }));
  if (result.kind !== "report") throw new Error("oczekiwano raportu");
  assertEquals(result.report.overall_rating, 4);
  assertEquals(calls.length, 1);
});

const orValidBody =
  JSON.stringify({
    choices: [{ message: { content: JSON.stringify({
      strengths: ["A"], gaps: [], action_items: [], overall_rating: 5,
    }) } }],
  });

function capturingTransport(bodies: unknown[]): Transport {
  return async (req) => {
    bodies.push(req.body);
    return new Response(orValidBody, {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  };
}

Deno.test("engine (K6): R3 — domyślnie userId trafia do upstreamu (parity)", async () => {
  const bodies: unknown[] = [];
  const engine = new Engine({ adapters, transport: capturingTransport(bodies) });
  await engine.execute(reportTask, [openrouterTrack], envWith({ SECRET_OR: secretOr }));
  assertEquals((bodies[0] as Record<string, unknown>).user, "u-1");
});

Deno.test("engine (K6): R3 — forwardUserId=false → userId wycięty z payloadu (kopia, wejście bez zmian)", async () => {
  const bodies: unknown[] = [];
  const engine = new Engine({
    adapters,
    transport: capturingTransport(bodies),
    forwardUserId: false,
  });
  await engine.execute(reportTask, [openrouterTrack], envWith({ SECRET_OR: secretOr }));
  assertEquals((bodies[0] as Record<string, unknown>).user, undefined);
  assertEquals(reportTask.userId, "u-1");
});

Deno.test("engine (K6): budżet maxAttempts — limit prób → budget:maxAttempts", async () => {
  const track = { ...openrouterTrack, models: ["m1", "m2"] };
  const engine = new Engine({
    adapters,
    transport: makeTransport(["empty", "empty"], []),
    budget: { maxAttempts: 1 },
  });
  const err = await expectCanonical(() =>
    engine.execute(reportTask, [track], envWith({ SECRET_OR: secretOr }))
  );
  assertEquals(err.code, "UPSTREAM_ERROR");
  assertEquals(err.providerDetail, "budget:maxAttempts");
});

Deno.test("engine (K6): budżet deadlineMs — przekroczenie czasu → budget:deadline (C-0 nie wchodzi)", async () => {
  const sleepingEmpty: Transport = async (req, baseUrl) => {
    await new Promise((r) => setTimeout(r, 60));
    const isGemini = baseUrl.includes("generativelanguage");
    const content = isGemini
      ? JSON.stringify({ candidates: [{ content: { parts: [{ text: "   " }] } }] })
      : JSON.stringify({ choices: [{ message: { content: "   " } }] });
    return new Response(content, {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  };
  const track = { ...openrouterTrack, models: ["m1", "m2"] };
  const engine = new Engine({
    adapters,
    transport: sleepingEmpty,
    budget: { deadlineMs: 5 },
  });
  const err = await expectCanonical(() =>
    engine.execute(reportTask, [track], envWith({ SECRET_OR: secretOr }))
  );
  assertEquals(err.code, "UPSTREAM_ERROR");
  assertEquals(err.providerDetail, "budget:deadline");
});

Deno.test("engine (K6): requestTimeoutMs (E4) — AbortSignal przerywa wiszący transport → timeout", async () => {
  const hangingTransport: Transport = (_req, _baseUrl, signal) =>
    new Promise((_resolve, reject) => {
      signal?.addEventListener("abort", () =>
        reject(new DOMException("aborted", "AbortError"))
      );
    });
  const engine = new Engine({
    adapters,
    transport: hangingTransport,
    requestTimeoutMs: 10,
  });
  const err = await expectCanonical(() =>
    engine.execute(reportTask, [openrouterTrack], envWith({ SECRET_OR: secretOr }))
  );
  assertEquals(err.code, "UPSTREAM_ERROR");
  assert(
    typeof err.providerDetail === "string" && err.providerDetail.includes("timeout"),
    `oczekiwano timeout, było: ${err.providerDetail}`,
  );
});