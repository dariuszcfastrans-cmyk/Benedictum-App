// Edge Function: gemini-proxy — Część C2.
// Proxy do Gemini API przez Supabase Edge Functions.
// Bezpieczeństwo:
//  - JWT walidowany przez platformę Supabase (verify_jwt) — 401 przed kodem funkcji.
//  - Rate-limit: atomowe RPC check_rate_limit (SECURITY DEFINER) przez Client B (service_role).
//  - CORS ograniczony do domen web (nie jest warstwą bezpieczeństwa dla aplikacji mobilnej).
//  - GEMINI_API_KEY wyłącznie z Supabase Secrets — NIGDY w kodzie ani w repo.
//  - Komunikaty błędów sanityzowane: bez kluczy API, tokenów JWT, ścieżek wewnętrznych.
import { createClient } from "jsr:@supabase/supabase-js@2";
// Persony rady doradczej. System prompty (EN) — własność intelektualna produktu.
// Persona: { senderId, systemPrompt }.
const PERSONAS = [
  {
    senderId: "critic",
    systemPrompt: "You are the Critic on an advisory board for career and negotiation training. " + "Your role: ask hard questions, find holes in the user's logic, challenge assumptions. " + "Be direct, precise, and demanding — but never personal. Keep responses concise (max 3 sentences)."
  },
  {
    senderId: "optimist",
    systemPrompt: "You are the Optimist on an advisory board for career and negotiation training. " + "Your role: identify strengths, reinforce confidence, point out what works. " + "Be warm, encouraging, and specific — always name the concrete strength. " + "Keep responses concise (max 3 sentences)."
  },
  {
    senderId: "coach",
    systemPrompt: "You are the Coach on an advisory board for career and negotiation training. " + "Your role: give actionable, practical feedback after each exchange. " + "Always end with one concrete next step the user can take. " + "Keep responses concise (max 3 sentences)."
  }
];
const CORS_ORIGINS = (()=>{
  // Domyślnie tylko lokalny dev web (flutter run -d chrome).
  const raw = Deno.env.get("CORS_ORIGINS") ?? "http://localhost:8899,http://localhost:3000";
  return raw.split(",").map((s)=>s.trim()).filter((s)=>s.length > 0);
})();
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
// Bazowy adres API Gemini (model konfigurowany w secrets).
const GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models";
function json(data, status = 200, headers = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...headers
    }
  });
}
function corsResponse() {
  const origin = CORS_ORIGINS.join(", ");
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization"
  };
}
// Sanityzacja: komunikat bezpieczny dla klienta — bez sekretów i ścieżek.
function safeErrorMessage(e) {
  const msg = e instanceof Error ? e.message : String(e);
  // Usuń potencjalne klucze API (kwoty są przykładowe, grep na repo = 0).
  const sanitized = msg.replace(/AIza[0-9A-Za-z_\-]{35}/g, "[REDACTED]").replace(/eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+/g, "[REDACTED]").replace(/sk-[A-Za-z0-9_\-]{20,}/g, "[REDACTED]");
  if (sanitized.length > 200) return sanitized.slice(0, 200) + "...";
  return sanitized;
}
// Wywołanie Gemini dla pojedynczej persony.
async function callGemini(persona, userMessage, scenario) {
  const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
  const url = `${GEMINI_API_URL}/${model}:generateContent`;
  const payload = {
    system_instruction: {
      parts: [
        {
          text: persona.systemPrompt
        }
      ]
    },
    contents: [
      {
        role: "user",
        parts: [
          {
            text: scenario ? `Scenariusz: ${scenario}` : ""
          },
          {
            text: userMessage
          }
        ].filter((p)=>p.text.length > 0)
      }
    ],
    generationConfig: {
      temperature: 0.7,
      maxOutputTokens: 300
    }
  };
  const res = await fetch(`${url}?key=${GEMINI_API_KEY}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify(payload)
  });
  if (!res.ok) {
    if (res.status === 429) throw new ApiUpstreamError(429, "GEMINI_RATE_LIMITED");
    if (res.status === 400 || res.status === 403) throw new ApiUpstreamError(503, "QUOTA_EXHAUSTED");
    throw new ApiUpstreamError(503, "GEMINI_UPSTREAM_ERROR");
  }
  const data = await res.json();
  const text = data?.candidates?.[0]?.content?.parts?.map((p)=>p.text ?? "").join("\n").trim();
  if (!text) throw new ApiUpstreamError(422, "EMPTY_RESPONSE");
  return text;
}
class ApiUpstreamError extends Error {
  status;
  code;
  constructor(status, code){
    super(code);
    this.status = status;
    this.code = code;
  }
}
// Walidacja body: { persona?, message, scenario }.
function validateBody(body) {
  if (!body || typeof body !== "object") throw new ApiUpstreamError(422, "INVALID_JSON");
  const b = body;
  if (typeof b.message !== "string" || b.message.trim().length === 0) {
    throw new ApiUpstreamError(422, "MISSING_MESSAGE");
  }
  if (typeof b.scenario !== "string" || b.scenario.trim().length === 0) {
    throw new ApiUpstreamError(422, "MISSING_SCENARIO");
  }
  if (b.persona !== undefined && b.persona !== null) {
    if (typeof b.persona !== "string" || !PERSONAS.some((p)=>p.senderId === b.persona)) {
      throw new ApiUpstreamError(422, "INVALID_PERSONA");
    }
  }
  return {
    persona: typeof b.persona === "string" ? b.persona : undefined,
    message: b.message.trim(),
    scenario: b.scenario.trim()
  };
}
Deno.serve(async (req)=>{
  const headers = corsResponse();
  // Preflight CORS.
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers
    });
  }
  if (req.method !== "POST") {
    return json({
      error: "METHOD_NOT_ALLOWED"
    }, 405, headers);
  }
  try {
    // Użytkownik uwierzytelniony przez platformę (verify_jwt). User ID z nagłówka.
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json({
        error: "UNAUTHORIZED"
      }, 401, headers);
    }
    // Client B (service_role) — do atomowego RPC rate-limit. service_role tylko tu, nigdy w app.
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceClient = createClient(supabaseUrl, serviceRoleKey);
    // Wyciągnięcie user_id z JWT (sub). Platforma zwalidowała podpis; parsujemy payload lokalnie.
    const token = authHeader.slice("Bearer ".length);
    const payloadPart = token.split(".")[1];
    let userId = null;
    if (payloadPart) {
      try {
        const decoded = JSON.parse(atob(payloadPart));
        userId = typeof decoded.sub === "string" ? decoded.sub : null;
      } catch  {
        userId = null;
      }
    }
    if (!userId) {
      return json({
        error: "UNAUTHORIZED"
      }, 401, headers);
    }
    // Rate-limit: atomowe RPC przez Client B — jedno wywołanie, bez SELECT+UPDATE w Deno.
    const { data: rpc, error: rpcError } = await serviceClient.rpc("check_rate_limit", {
      p_user_id: userId
    });
    if (rpcError) {
      return json({
        error: safeErrorMessage(rpcError.message)
      }, 503, headers);
    }
    const allowed = rpc?.allowed === true;
    if (!allowed) {
      return json({
        error: "RATE_LIMITED",
        remaining: 0,
        retry_after_seconds: 60
      }, 429, headers);
    }
    // Walidacja body.
    let body;
    try {
      body = validateBody(await req.json());
    } catch (e) {
      const code = e instanceof ApiUpstreamError ? e.code : "INVALID_JSON";
      return json({
        error: code
      }, e instanceof ApiUpstreamError ? e.status : 422, headers);
    }
    // Wykonanie Gemini.
    const targets = body.persona ? PERSONAS.filter((p)=>p.senderId === body.persona) : PERSONAS;
    const results = {};
    for (const persona of targets){
      const text = await callGemini(persona, body.message, body.scenario);
      results[persona.senderId] = text;
    }
    return json({
      ...results,
      remaining: rpc?.remaining ?? 0
    }, 200, headers);
  } catch (e) {
    if (e instanceof ApiUpstreamError) {
      return json({
        error: e.code
      }, e.status, headers);
    }
    return json({
      error: "INTERNAL_ERROR"
    }, 503, headers);
  }
});
