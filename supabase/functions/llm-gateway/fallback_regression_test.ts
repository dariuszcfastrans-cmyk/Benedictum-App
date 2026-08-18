// Test regresyjny KROKU 7 dla llm-gateway (thin host na engine):
//  1) report: C-0 przez engine — EMPTY_RESPONSE → next, INVALID_REPORT → next, wynik z 3. modelu,
//  2) chat z persona target (critic) — odpowiedź { critic, remaining }, bez innych person,
//  3) upstream 429 (RATE_LIMITED) — mapowanie CanonicalError → HTTP 429 + retry_after_seconds.
// Uruchamianie: deno run --node-modules-dir=none --cached-only --allow-net --allow-env \
//   supabase/functions/llm-gateway/fallback_regression_test.ts
const realFetch = globalThis.fetch;

let geminiCalls = 0;
let openrouterCalls = 0;
let rpcCalls = 0;

globalThis.fetch = (async (input: RequestInfo | URL, _init?: RequestInit) => {
  const url = String(input);
  if (url.includes("/rest/v1/rpc/check_rate_limit")) {
    rpcCalls++;
    return new Response(JSON.stringify({ allowed: true, remaining: 4 }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }
  if (url.includes("generativelanguage.googleapis.com")) {
    geminiCalls++;
    if (url.includes("rate-limited-model")) {
      return new Response(JSON.stringify({ error: "rate" }), {
        status: 429,
        headers: { "Content-Type": "application/json", "Retry-After": "3" },
      });
    }
    const content = (text: string) =>
      JSON.stringify({ candidates: [{ content: { parts: [{ text }] } }] });
    if (geminiCalls === 1) {
      // EMPTY_RESPONSE: pusta treść po trimie.
      return new Response(content("  "), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
    if (geminiCalls === 2) {
      // INVALID_REPORT: tekst obecny, ale nie jest poprawnym raportem.
      return new Response(content("to nie jest raport"), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
    // Trzeci model: poprawny raport wg kontraktu parseReport.
    const validReport = JSON.stringify({
      strengths: ["A"],
      gaps: ["B"],
      action_items: ["C"],
      overall_rating: 4,
    });
    return new Response(content(validReport), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }
  if (url.includes("openrouter.ai/api/v1/chat/completions")) {
    openrouterCalls++;
    return new Response(
      JSON.stringify({ choices: [{ message: { content: "Odpowiedź krytyka" } }] }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  }
  return new Response(JSON.stringify({ error: "unexpected" }), { status: 500 });
}) as typeof fetch;

const TRACKS_GEMINI = JSON.stringify([
  {
    id: "gemini-1",
    name: "Gemini",
    description: "test",
    provider: "gemini",
    carrier: { kind: "secret-json", secretName: "SECRET_GEMINI" },
    models: ["modelA", "modelB", "modelC"],
    capabilities: ["text"],
    required: true,
  },
]);
const TRACKS_OPENROUTER = JSON.stringify([
  {
    id: "openrouter-1",
    name: "OpenRouter",
    description: "test",
    provider: "openrouter",
    carrier: { kind: "secret-json", secretName: "SECRET_OPENROUTER" },
    models: ["modelA"],
    capabilities: ["text"],
    required: true,
  },
]);
const TRACKS_RATE_LIMITED = JSON.stringify([
  {
    id: "gemini-rl",
    name: "Gemini RL",
    description: "test",
    provider: "gemini",
    carrier: { kind: "secret-json", secretName: "SECRET_GEMINI" },
    models: ["rate-limited-model"],
    capabilities: ["text"],
    required: true,
  },
]);

Deno.env.set("SUPABASE_URL", "https://mock.supabase.co");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "mock-service-role");
Deno.env.set("SECRET_GEMINI", JSON.stringify({ apiKey: "gk" }));
Deno.env.set("SECRET_OPENROUTER", JSON.stringify({ apiKey: "ok" }));
Deno.env.set("CORS_ORIGINS", "http://localhost:8899,http://localhost:3000");

await import("./index.ts");
await new Promise((r) => setTimeout(r, 400));

const jwtPayload = btoa(JSON.stringify({ sub: "test-user" }));
const token = `${btoa(JSON.stringify({ alg: "none" }))}.${jwtPayload}.x`;

async function post(body: unknown) {
  return realFetch("http://localhost:8000/", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(body),
  });
}

async function main() {
  // 1) report: C-0 przez engine (3 wywołania gemini) + rate-limit RPC + JWT.
  Deno.env.set("LLM_TRACKS", TRACKS_GEMINI);
  const r1 = await post({ mode: "report", scenario: "Test", context: "Kontekst testowy" });
  const d1 = await r1.json();
  if (r1.status !== 200) throw new Error(`[1] status=${r1.status} body=${JSON.stringify(d1)}`);
  if (d1.report?.overall_rating !== 4) {
    throw new Error(`[1] raport nie z 3. modelu: ${JSON.stringify(d1.report)}`);
  }
  if (geminiCalls !== 3) throw new Error(`[1] oczekiwano 3 wywołań gemini, było ${geminiCalls}`);

  // 2) chat z persona (critic): { critic, remaining }, bez innych person.
  Deno.env.set("LLM_TRACKS", TRACKS_OPENROUTER);
  const r2 = await post({ persona: "critic", message: "Cześć", scenario: "Test" });
  const d2 = await r2.json();
  if (r2.status !== 200) throw new Error(`[2] status=${r2.status} body=${JSON.stringify(d2)}`);
  if (typeof d2.critic !== "string" || d2.critic.length === 0) throw new Error("[2] brak critic");
  if (d2.optimist !== undefined || d2.coach !== undefined) throw new Error("[2] nieproszone persony");
  if (d2.remaining !== 4) throw new Error(`[2] brak remaining`);
  if (openrouterCalls !== 1) {
    throw new Error(`[2] oczekiwano 1 wywołania openrouter, było ${openrouterCalls}`);
  }

  // 3) upstream 429 → RATE_LIMITED (429 + retry_after_seconds z nagłówka Retry-After).
  Deno.env.set("LLM_TRACKS", TRACKS_RATE_LIMITED);
  const r3 = await post({ mode: "report", scenario: "Test", context: "Kontekst testowy" });
  const d3 = await r3.json();
  if (r3.status !== 429) throw new Error(`[3] status=${r3.status} body=${JSON.stringify(d3)}`);
  if (d3.error !== "RATE_LIMITED") throw new Error(`[3] error=${d3.error}`);
  if (d3.retry_after_seconds !== 3) throw new Error(`[3] retry_after_seconds=${d3.retry_after_seconds}`);

  if (rpcCalls !== 3) throw new Error(`oczekiwano 3 wywołań RPC, było ${rpcCalls}`);
  console.log(
    `OK llm-gateway: report C-0, chat persona, RATE_LIMITED; gemini=${geminiCalls} openrouter=${openrouterCalls} RPC=${rpcCalls}`,
  );
}

try {
  await main();
  Deno.exit(0);
} catch (e) {
  console.error("FAIL llm-gateway:", e);
  Deno.exit(1);
}