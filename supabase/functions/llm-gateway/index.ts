// Edge Function: llm-gateway (KROK 7) — THIN HOST na silniku LLM Foundation v2.0.
// Sekwencja: JWT-userId → rate-limit RPC → validateBody → engine.execute → HTTP.
// Kontrakt odpowiedzi: IDENTYCZNY z legacy proxy (openrouter-proxy / gemini-proxy) —
// klient Flutter nie wymaga zmian semantycznych (tylko switch funkcji, KROK 7).
// Konfiguracja (Supabase Secrets):
//  - LLM_TRACKS            — JSON: tablica tracków wg validateExecutionTrack (nośnik secret-json),
//  - sekrety nośników      — JSON {"apiKey": "…"} (nazwa = track.carrier.secretName),
//  - opcjonalnie           — LLM_MAX_ATTEMPTS / LLM_DEADLINE_MS / LLM_REQUEST_TIMEOUT_MS (budżet KROKU 6),
//  - standard              — SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, CORS_ORIGINS.
// Legacy proxy (gemini-proxy, openrouter-proxy) usunięte w KROKU 8 — to jedyny host LLM.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { PERSONAS } from "../_shared/prompts/index.ts";
import { parseTracks } from "../_shared/engine/registry.ts";
import { Engine, type EngineEnv } from "../_shared/engine/engine.ts";
import { CapabilityPolicy, DataPolicy } from "../_shared/engine/policies.ts";
import { geminiAdapter } from "../_shared/adapters/gemini.ts";
import { openrouterAdapter } from "../_shared/adapters/openrouter.ts";
import { CanonicalError, type ExecutionTrack, type TaskSpec } from "../_shared/core/index.ts";
import {
  ApiUpstreamError,
  corsResponse,
  decodeJwtUserId,
  json,
  safeErrorMessage,
  validateBody,
  type ChatBody,
  type ReportBody,
} from "../_shared/host.ts";

/// Opcjonalny int z env (0/brak/niepoprawny → undefined = bez limitu, parity z proxy).
function optionalInt(name: string): number | undefined {
  const raw = Deno.env.get(name);
  if (!raw || raw.trim() === "") return undefined;
  const n = Number(raw.trim());
  return Number.isInteger(n) && n > 0 ? n : undefined;
}

/// Composition root (KROK 6: IExecutionEngine + łańcuch polityk + budżet opt-in).
const engine = new Engine({
  adapters: { gemini: geminiAdapter, openrouter: openrouterAdapter },
  policies: [new CapabilityPolicy(), new DataPolicy()],
  budget: {
    maxAttempts: optionalInt("LLM_MAX_ATTEMPTS"),
    deadlineMs: optionalInt("LLM_DEADLINE_MS"),
  },
  requestTimeoutMs: optionalInt("LLM_REQUEST_TIMEOUT_MS"),
});

const env: EngineEnv = { getSecret: (name) => Deno.env.get(name) };

function loadTracks(): ExecutionTrack[] {
  try {
    return parseTracks(Deno.env.get("LLM_TRACKS") ?? "");
  } catch (e) {
    console.error("llm-gateway: LLM_TRACKS:", safeErrorMessage(e));
    throw new ApiUpstreamError(503, "NOT_CONFIGURED");
  }
}

function chatTask(body: ChatBody, persona: string, userId: string): TaskSpec {
  return {
    kind: "chat",
    scenario: body.scenario,
    context: body.context,
    persona,
    message: body.message,
    mode: body.mode,
    userId,
    capabilities: ["text"],
    maxTokens: 300,
    temperature: 0.7,
  };
}

function reportTask(body: ReportBody, userId: string): TaskSpec {
  return {
    kind: "report",
    scenario: body.scenario,
    context: body.context,
    userId,
    capabilities: ["text"],
    maxTokens: 800,
    temperature: 0.4,
  };
}

function errorResponse(e: CanonicalError, headers: HeadersInit): Response {
  if (e.code === "RATE_LIMITED") {
    return json(
      { error: e.code, retry_after_seconds: e.retryAfterSeconds ?? 60 },
      429,
      headers,
    );
  }
  // providerDetail tylko w logach; odpowiedź sanitarna (sam kanoniczny kod).
  if (e.providerDetail) {
    console.error(`llm-gateway: ${e.code} ${e.providerDetail}`);
  }
  return json({ error: e.code }, e.status, headers);
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
    const userId = decodeJwtUserId(req.headers.get("Authorization") ?? "");
    if (!userId) {
      return json({ error: "UNAUTHORIZED" }, 401, headers);
    }

    const serviceClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );
    const { data: rpc, error: rpcError } = await serviceClient.rpc(
      "check_rate_limit",
      { p_user_id: userId },
    );
    if (rpcError) {
      return json({ error: safeErrorMessage(rpcError.message) }, 503, headers);
    }
    if (rpc?.allowed !== true) {
      return json(
        { error: "RATE_LIMITED", remaining: 0, retry_after_seconds: 60 },
        429,
        headers,
      );
    }

    let body;
    try {
      body = validateBody(await req.json());
    } catch (e) {
      const code = e instanceof ApiUpstreamError ? e.code : "INVALID_JSON";
      return json({ error: code }, e instanceof ApiUpstreamError ? e.status : 422, headers);
    }

    const tracks = loadTracks();

    if (body.mode === "report") {
      const result = await engine.execute(reportTask(body, userId), tracks, env);
      if (result.kind !== "report") {
        throw new CanonicalError({ code: "INVALID_REPORT" });
      }
      return json({ report: result.report, remaining: rpc?.remaining ?? 0 }, 200, headers);
    }

    const targets = body.mode === "intake"
      ? PERSONAS.filter((p) => p.senderId === "coach")
      : body.persona
      ? PERSONAS.filter((p) => p.senderId === body.persona)
      : PERSONAS;

    const results: Record<string, string> = {};
    for (const persona of targets) {
      const result = await engine.execute(chatTask(body, persona.senderId, userId), tracks, env);
      if (result.kind !== "chat") {
        throw new CanonicalError({ code: "EMPTY_RESPONSE" });
      }
      results[persona.senderId] = result.text;
    }
    return json({ ...results, remaining: rpc?.remaining ?? 0 }, 200, headers);
  } catch (e) {
    if (e instanceof CanonicalError) {
      return errorResponse(e, headers);
    }
    if (e instanceof ApiUpstreamError) {
      if (e.status === 429) {
        return json(
          { error: e.code, retry_after_seconds: e.retryAfterSeconds ?? 60 },
          429,
          headers,
        );
      }
      return json({ error: e.code }, e.status, headers);
    }
    console.error("llm-gateway:", safeErrorMessage(e));
    return json({ error: "INTERNAL_ERROR" }, 503, headers);
  }
});