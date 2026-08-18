// Brama KROKU 2 (_shared/ extraction):
//  - moduły współdzielone (prompts, backoff) ładują się i zachowują publiczne API,
//  - oba proxy importują prompts/backoff wyłącznie z ../_shared/ (koniec B1),
//  - stare ścieżki fizycznie nie istnieją (koniec duplikacji).
// Uruchom: deno test --allow-read supabase/functions/_shared/import_gate_test.ts

import { assertEquals } from "jsr:@std/assert";

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(`GATE_FAILED: ${msg}`);
}

const fnRoot = `${import.meta.dirname}/..`;

const prompts = await import("./prompts/index.ts");
const backoff = await import("./backoff.ts");

Deno.test("brama K2: _shared/prompts zachowuje publiczne API", () => {
  assert(Array.isArray(prompts.PERSONAS) && prompts.PERSONAS.length >= 3, "PERSONAS");
  for (const name of ["escapeXml", "renderSystemPrompt", "renderReportPrompt", "parseReport"] as const) {
    assert(typeof prompts[name] === "function", `brak eksportu ${name}`);
  }
  const r = prompts.parseReport(
    JSON.stringify({ strengths: ["A"], gaps: ["B"], action_items: ["C"], overall_rating: 4 }),
  );
  assert(r !== null && r.overall_rating === 4, "parseReport zwraca kontrakt");
});

Deno.test("brama K2: _shared/backoff zachowuje publiczne API", () => {
  assert(typeof backoff.extractRetryAfter === "function", "extractRetryAfter");
  const res = new Response(null, { headers: { "Retry-After": "30" } });
  assertEquals(backoff.extractRetryAfter(res), 30);
});

Deno.test("brama K2: stare ścieżki (prompts/backoff w proxy) fizycznie nie istnieją", async () => {
  const stale = [
    `${fnRoot}/gemini-proxy/prompts`,
    `${fnRoot}/gemini-proxy/backoff.ts`,
    `${fnRoot}/openrouter-proxy/backoff.ts`,
    `${fnRoot}/openrouter-proxy/backoff_test.ts`,
  ];
  for (const p of stale) {
    let exists = true;
    try {
      await Deno.stat(p);
    } catch {
      exists = false;
    }
    assert(!exists, `stara ścieżka nadal istnieje: ${p}`);
  }
});

Deno.test("brama K3: core/index.ts jest czysty (zero importów zewnętrznych)", async () => {
  const coreSrc = await Deno.readTextFile(`${import.meta.dirname}/core/index.ts`);
  assert(!coreSrc.includes("import "), "core nie może mieć importów (czysty moduł typów)");
  assert(coreSrc.includes("export type ReportContract"), "brak kontraktu ReportContract w core");
});

Deno.test("brama K3: prompts re-eksportuje ReportContract z core (brak dryfu)", async () => {
  const promptsSrc = await Deno.readTextFile(`${import.meta.dirname}/prompts/index.ts`);
  assert(
    promptsSrc.includes('from "../core/index.ts"'),
    "prompts nie importuje kontraktu z core",
  );
});

// Brama KROKU 4 (adaptery — czyste tłumacze bez transportu; parseReport przeniesiony do core).
const adapterFiles = ["types.ts", "gemini.ts", "openrouter.ts"];

Deno.test("brama K4: adaptery są czyste — bez fetch/Deno/jsr/npm", async () => {
  for (const f of adapterFiles) {
    const src = await Deno.readTextFile(`${import.meta.dirname}/adapters/${f}`);
    assert(!src.includes("fetch("), `${f}: adapter nie może wykonywać fetch`);
    assert(!src.includes("Deno."), `${f}: adapter nie może używać Deno`);
    assert(!src.includes("jsr:") && !src.includes("npm:"), `${f}: zero zależności zewnętrznych`);
    assert(!src.includes("globalThis"), `${f}: brak globalnych stubów/harness`);
  }
});

Deno.test("brama K4: parseReport jest kanonem w core (prompts tylko re-eksportuje)", async () => {
  const coreSrc = await Deno.readTextFile(`${import.meta.dirname}/core/index.ts`);
  const promptsSrc = await Deno.readTextFile(`${import.meta.dirname}/prompts/index.ts`);
  assert(coreSrc.includes("export function parseReport"), "brak parseReport w core");
  assert(
    promptsSrc.includes('export { parseReport } from "../core/index.ts"'),
    "prompts nie re-eksportuje parseReport z core",
  );
  assert(!promptsSrc.includes("export function parseReport"), "parseReport zdefiniowany w prompts (dryf!)");
  for (const f of adapterFiles) {
    const src = await Deno.readTextFile(`${import.meta.dirname}/adapters/${f}`);
    if (src.includes("parseReport")) {
      assert(
        src.includes('from "../core/index.ts"'),
        `${f}: parseReport importowany spoza core`,
      );
    }
  }
});

// Brama KROKU 5 (engine — transport + registry + router; D/17 provider; D/18 baseUrl/mapError).

Deno.test("brama K5: router.ts i registry.ts są czyste (bez fetch/Deno/jsr/npm)", async () => {
  for (const f of ["router.ts", "registry.ts"]) {
    const src = await Deno.readTextFile(`${import.meta.dirname}/engine/${f}`);
    assert(!src.includes("fetch("), `${f}: router/registry to nie warstwa transportu`);
    assert(!src.includes("Deno."), `${f}: brak dostępu do środowiska`);
    assert(!src.includes("jsr:") && !src.includes("npm:"), `${f}: zero zależności zewnętrznych`);
  }
});

Deno.test("brama K5: engine.ts ma transport (fetch) ale zero zależności zewnętrznych", async () => {
  const src = await Deno.readTextFile(`${import.meta.dirname}/engine/engine.ts`);
  assert(src.includes("export const fetchTransport"), "brak fetchTransport w engine");
  assert(!src.includes("jsr:") && !src.includes("npm:"), "engine: zero zależności zewnętrznych");
});

Deno.test("brama K5: ExecutionTrack ma provider; adaptery mają baseUrl i mapError", async () => {
  const coreSrc = await Deno.readTextFile(`${import.meta.dirname}/core/index.ts`);
  assert(coreSrc.includes("provider: string;"), "brak pola provider w ExecutionTrack (core)");
  const typesSrc = await Deno.readTextFile(`${import.meta.dirname}/adapters/types.ts`);
  assert(typesSrc.includes("readonly baseUrl: string;"), "brak baseUrl w LlmAdapter");
  assert(typesSrc.includes("mapError("), "brak mapError w LlmAdapter");
  for (const f of ["gemini.ts", "openrouter.ts"]) {
    const src = await Deno.readTextFile(`${import.meta.dirname}/adapters/${f}`);
    assert(src.includes("baseUrl:"), `${f}: brak implementacji baseUrl`);
    assert(src.includes("mapError("), `${f}: brak implementacji mapError`);
  }
});

// Brama KROKU 6 (polityki tracków + utwardzenie engine — IExecutionEngine/budżet/timeout/R3).

Deno.test("brama K6: policies.ts jest czysta (bez fetch/Deno/jsr/npm)", async () => {
  const src = await Deno.readTextFile(`${import.meta.dirname}/engine/policies.ts`);
  assert(!src.includes("fetch("), "policies: polityki nie mogą wykonywać fetch");
  assert(!src.includes("Deno."), "policies: brak dostępu do środowiska");
  assert(!src.includes("jsr:") && !src.includes("npm:"), "policies: zero zależności zewnętrznych");
  assert(src.includes("import "), "policies musi importować kontrakt z core");
});

Deno.test("brama K6: core ma TrackPolicy, DataPolicyDeclaration i dataPolicy (additive)", async () => {
  const coreSrc = await Deno.readTextFile(`${import.meta.dirname}/core/index.ts`);
  assert(coreSrc.includes("export interface TrackPolicy"), "brak TrackPolicy w core");
  assert(coreSrc.includes("export type DataPolicyDeclaration"), "brak DataPolicyDeclaration w core");
  assert(coreSrc.includes("dataPolicy?: DataPolicyDeclaration"), "brak dataPolicy w ExecutionTrack");
  assert(!coreSrc.includes("import "), "core nadal czysty (zero importów)");
});

Deno.test("brama K6: engine ma IExecutionEngine, łańcuch polityk, R3, budżet i timeout (E4)", async () => {
  const src = await Deno.readTextFile(`${import.meta.dirname}/engine/engine.ts`);
  assert(src.includes("export interface IExecutionEngine"), "brak IExecutionEngine");
  assert(src.includes("class Engine implements IExecutionEngine"), "Engine nie implementuje interfejsu");
  assert(src.includes("policies?: TrackPolicy[]"), "brak łańcucha polityk w EngineDeps");
  assert(src.includes("forwardUserId?: boolean"), "brak forwardUserId (R3) w EngineDeps");
  assert(src.includes("budget?: EngineBudget"), "brak budżetu w EngineDeps");
  assert(src.includes("requestTimeoutMs?: number"), "brak requestTimeoutMs (E4) w EngineDeps");
  assert(src.includes("AbortController"), "brak AbortController (timeout) w engine");
  assert(!src.includes("jsr:") && !src.includes("npm:"), "engine: zero zależności zewnętrznych");
});

// Brama KROKU 7 (llm-gateway — thin host + wspólne moduły hosta).

Deno.test("brama K7: _shared/host.ts eksportuje API hosta", async () => {
  const src = await Deno.readTextFile(`${import.meta.dirname}/host.ts`);
  for (const name of ["validateBody", "corsResponse", "json", "decodeJwtUserId", "safeErrorMessage"]) {
    assert(src.includes(`export function ${name}`), `brak eksportu ${name}`);
  }
  assert(src.includes("export class ApiUpstreamError"), "brak ApiUpstreamError");
  assert(src.includes('from "./prompts/index.ts"'), "host nie używa PERSONAS z prompts");
});

Deno.test("brama K7: llm-gateway to thin host — kompozycja, nie duplikacja", async () => {
  const src = await Deno.readTextFile(`${fnRoot}/llm-gateway/index.ts`);
  assert(src.includes('from "../_shared/host.ts"'), "gateway nie używa _shared/host");
  assert(src.includes('from "../_shared/engine/engine.ts"'), "gateway nie używa engine");
  assert(src.includes("engine.execute("), "gateway nie deleguje do engine.execute");
  assert(src.includes("jsr:@supabase/supabase-js@2"), "gateway nie ma klienta Supabase (rate-limit)");
  assert(!src.includes("renderSystemPrompt"), "gateway nie duplikuje promptów");
  assert(!src.includes("renderReportPrompt"), "gateway nie duplikuje promptów raportu");
  assert(!src.includes('"choices"'), "gateway nie parsuje payloadów providera (adaptery)");
  assert(!src.includes('"candidates"'), "gateway nie parsuje payloadów providera (adaptery)");
});

// Brama KROKU 8 (deprecacja legacy proxy — llm-gateway jedynym hostem LLM).

Deno.test("brama K8: legacy proxy (gemini-proxy, openrouter-proxy) nie istnieją", async () => {
  for (const dir of ["gemini-proxy", "openrouter-proxy"]) {
    let exists = true;
    try {
      await Deno.stat(`${fnRoot}/${dir}`);
    } catch {
      exists = false;
    }
    assert(!exists, `legacy proxy nadal istnieje: ${dir}`);
  }
});

Deno.test("brama K8: llm-gateway ma harness regresyjny + e2e_smoke (trwały artefakt Fali 2B)", async () => {
  await Deno.stat(`${fnRoot}/llm-gateway/fallback_regression_test.ts`);
  const e2e = await Deno.readTextFile(`${fnRoot}/llm-gateway/e2e_smoke_test.ts`);
  assert(e2e.includes("${FN_BASE}/llm-gateway"), "e2e_smoke nie wskazuje llm-gateway");
  assert(!e2e.includes("/openrouter-proxy"), "e2e_smoke odwołuje się do legacy proxy");
});

Deno.test("brama K8: klient Flutter bez fallbacku legacy (llm-gateway domyślnie)", async () => {
  const root = `${import.meta.dirname}/../../../lib`;
  const src = await Deno.readTextFile(`${root}/services/supabase_api_service.dart`);
  assert(src.includes("'llm-gateway'"), "klient nie używa llm-gateway jako domyślnego");
  assert(!src.includes("openrouter-proxy"), "klient odwołuje się do legacy openrouter-proxy");
  assert(!src.includes("gemini-proxy"), "klient odwołuje się do legacy gemini-proxy");
  assert(src.includes("useLlmFunction"), "brak runtime switch (useLlmFunction)");
});