// Edge Function: openrouter-proxy.
// Alternatywny provider LLM dla Benedictum, bez zmian kontraktu odpowiedzi.
// Bezpieczeństwo:
//  - JWT walidowany przez platformę Supabase (verify_jwt) — 401 przed kodem.
//  - Rate-limit: atomowe RPC check_rate_limit przez service_role.
//  - OPENROUTER_API_KEY tylko z Supabase Secrets.
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  PERSONAS,
  renderSystemPrompt,
  renderReportPrompt,
  parseReport,
  type PromptMode,
} from "../gemini-proxy/prompts/index.ts";

const CORS_ORIGINS = (() => {
  const raw = Deno.env.get("CORS_ORIGINS") ??
    "http://localhost:8899,http://localhost:3000";
  return raw.split(",").map((s) => s.trim()).filter((s) => s.length > 0);
})();

const OPENROUTER_API_URL = "https://openrouter.ai/api/v1/chat/completions";

function json(data: unknown, status = 200, headers: HeadersInit = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...headers,
    },
  });
}

function corsResponse() {
  const origin = CORS_ORIGINS.join(", ");
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };
}

function safeErrorMessage(e: unknown) {
  const msg = e instanceof Error ? e.message : String(e);
  const sanitized = msg
    .replace(/AIza[0-9A-Za-z_\-]{35}/g, "[REDACTED]")
    .replace(/sk-[A-Za-z0-9_\-]{20,}/g, "[REDACTED]")
    .replace(/eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+/g, "[REDACTED]");
  if (sanitized.length > 200) return sanitized.slice(0, 200) + "...";
  return sanitized;
}

class ApiUpstreamError extends Error {
  status: number;
  code: string;
  constructor(status: number, code: string) {
    super(code);
    this.status = status;
    this.code = code;
  }
}

/// Walidowane body dla trybów rozmowy (intake/analyze).
type ChatBody = {
  mode: "intake" | "analyze";
  persona?: string;
  message: string;
  scenario: string;
  context?: string;
};

/// Walidowane body dla trybu raportu (mode:"report").
type ReportBody = {
  mode: "report";
  scenario: string;
  context: string;
};

function validateBody(body: unknown): ChatBody | ReportBody {
  if (!body || typeof body !== "object") {
    throw new ApiUpstreamError(422, "INVALID_JSON");
  }
  const b = body as Record<string, unknown>;

  // Tryb "report": raport generowany z kontekstu sesji (scenario + context).
  if (b.mode === "report") {
    if (typeof b.scenario !== "string" || b.scenario.trim().length === 0) {
      throw new ApiUpstreamError(422, "MISSING_SCENARIO");
    }
    if (typeof b.context !== "string" || b.context.trim().length === 0) {
      throw new ApiUpstreamError(422, "MISSING_CONTEXT");
    }
    return {
      mode: "report",
      scenario: b.scenario.trim(),
      context: b.context.trim(),
    };
  }

  if (typeof b.message !== "string" || b.message.trim().length === 0) {
    throw new ApiUpstreamError(422, "MISSING_MESSAGE");
  }
  if (typeof b.scenario !== "string" || b.scenario.trim().length === 0) {
    throw new ApiUpstreamError(422, "MISSING_SCENARIO");
  }
  if (b.persona !== undefined && b.persona !== null) {
    if (
      typeof b.persona !== "string" ||
      !PERSONAS.some((p) => p.senderId === b.persona)
    ) {
      throw new ApiUpstreamError(422, "INVALID_PERSONA");
    }
  }
  // Opcjonalny tryb rozmowy: "intake" (Coach-wywiad) | "analyze" (domyślny).
  if (b.mode !== undefined && b.mode !== null) {
    if (b.mode !== "intake" && b.mode !== "analyze") {
      throw new ApiUpstreamError(422, "INVALID_MODE");
    }
  }
  return {
    persona: typeof b.persona === "string" ? b.persona : undefined,
    message: b.message.trim(),
    scenario: b.scenario.trim(),
    context: typeof b.context === "string" ? b.context.trim() : undefined,
    mode: (b.mode === "intake" ? "intake" : "analyze"),
  };
}

/// Wywołanie OpenRouter dla raportu końcowego (mode:"report") — 1 wywołanie LLM.
async function callOpenRouterReport(
  scenario: string,
  context: string,
  userId: string,
) {
  const openRouterKey = Deno.env.get("OPENROUTER_API_KEY") ?? "";
  if (!openRouterKey) {
    throw new ApiUpstreamError(503, "OPENROUTER_NOT_CONFIGURED");
  }

  const models = (Deno.env.get("OPENROUTER_MODEL") ?? "openrouter/free")
    .split(",")
    .map((m) => m.trim())
    .filter((m) => m.length > 0);

  const systemText = renderReportPrompt(scenario, context);
  const payload = (model: string) => ({
    model,
    messages: [
      { role: "system", content: systemText },
      { role: "user", content: "Wygeneruj raport końcowy sesji." },
    ],
    temperature: 0.4,
    max_tokens: 800,
    reasoning: { enabled: false },
    user: userId,
  });

  let lastError: ApiUpstreamError | null = null;
  for (const model of models) {
    const res = await fetch(OPENROUTER_API_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openRouterKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload(model)),
    });

    if (res.ok) {
      const text = await extractContent(res);
      const report = parseReport(text);
      if (!report) throw new ApiUpstreamError(422, "INVALID_REPORT");
      return report;
    }

    if (res.status === 429) {
      throw new ApiUpstreamError(429, "OPENROUTER_RATE_LIMITED");
    }
    if (res.status === 404) {
      lastError = new ApiUpstreamError(
        503,
        `OPENROUTER_MODEL_OR_POLICY_BLOCKED:${model}`,
      );
      continue;
    }
    if ([400, 401, 402, 403].includes(res.status)) {
      lastError = new ApiUpstreamError(
        503,
        `OPENROUTER_CREDENTIALS_OR_QUOTA:${model}`,
      );
      continue;
    }
    lastError = new ApiUpstreamError(
      503,
      `OPENROUTER_UPSTREAM_ERROR:${model}`,
    );
  }

  throw lastError ?? new ApiUpstreamError(503, "OPENROUTER_NO_MODELS");
}

async function callOpenRouter(
  persona: (typeof PERSONAS)[number],
  userMessage: string,
  scenario: string,
  userId: string,
  options: { context?: string; mode?: PromptMode } = {},
) {
  const openRouterKey = Deno.env.get("OPENROUTER_API_KEY") ?? "";

  if (!openRouterKey) {
    throw new ApiUpstreamError(503, "OPENROUTER_NOT_CONFIGURED");
  }

  const models = (Deno.env.get("OPENROUTER_MODEL") ?? "openrouter/free")
    .split(",")
    .map((m) => m.trim())
    .filter((m) => m.length > 0);

  const systemText = renderSystemPrompt(persona, scenario, userMessage, {
    context: options.context,
    mode: options.mode,
  });
  const payload = (model: string) => ({
    model,
    messages: [
      { role: "system", content: systemText },
      { role: "user", content: userMessage },
    ],
    temperature: 0.7,
    max_tokens: 300,
    reasoning: { enabled: false },
    user: userId,
  });

  let lastError: ApiUpstreamError | null = null;
  for (const model of models) {
    const res = await fetch(OPENROUTER_API_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openRouterKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload(model)),
    });

    if (res.ok) {
      return await extractContent(res);
    }

    if (res.status === 429) {
      throw new ApiUpstreamError(429, "OPENROUTER_RATE_LIMITED");
    }
    if (res.status === 404) {
      lastError = new ApiUpstreamError(
        503,
        `OPENROUTER_MODEL_OR_POLICY_BLOCKED:${model}`,
      );
      continue;
    }
    if ([400, 401, 402, 403].includes(res.status)) {
      lastError = new ApiUpstreamError(
        503,
        `OPENROUTER_CREDENTIALS_OR_QUOTA:${model}`,
      );
      continue;
    }
    lastError = new ApiUpstreamError(
      503,
      `OPENROUTER_UPSTREAM_ERROR:${model}`,
    );
  }

  throw lastError ?? new ApiUpstreamError(503, "OPENROUTER_NO_MODELS");
}

async function extractContent(res: Response) {
  const data = await res.json();
  const content = data?.choices?.[0]?.message?.content;
  const text = typeof content === "string"
    ? content.trim()
    : Array.isArray(content)
    ? content
      .map((p: unknown) =>
        typeof p === "object" && p && "text" in p
          ? String((p as Record<string, unknown>).text ?? "")
          : ""
      )
      .join("\n")
      .trim()
    : "";

  if (!text) throw new ApiUpstreamError(422, "EMPTY_RESPONSE");
  return text;
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
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json({ error: "UNAUTHORIZED" }, 401, headers);
    }

    const token = authHeader.slice("Bearer ".length);
    const payloadPart = token.split(".")[1];
    let userId: string | null = null;
    if (payloadPart) {
      try {
        const decoded = JSON.parse(atob(payloadPart));
        userId = typeof decoded.sub === "string" ? decoded.sub : null;
      } catch {
        userId = null;
      }
    }
    if (!userId) {
      return json({ error: "UNAUTHORIZED" }, 401, headers);
    }

    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceClient = createClient(supabaseUrl, serviceRoleKey);
    const { data: rpc, error: rpcError } = await serviceClient.rpc(
      "check_rate_limit",
      { p_user_id: userId },
    );
    if (rpcError) {
      return json({ error: safeErrorMessage(rpcError.message) }, 503, headers);
    }
    if (rpc?.allowed !== true) {
      return json(
        {
          error: "RATE_LIMITED",
          remaining: 0,
          retry_after_seconds: 60,
        },
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

    // Tryb "report": 1 wywołanie LLM → raport + walidacja kontraktu.
    if (body.mode === "report") {
      const report = await callOpenRouterReport(
        body.scenario,
        body.context,
        userId,
      );
      return json({ report, remaining: rpc?.remaining ?? 0 }, 200, headers);
    }

    // Tryb "intake" prowadzi wyłącznie Coach; "analyze" (domyślny) analizuje
    // wybrane persony (albo wszystkie przy braku persona).
    const targets = body.mode === "intake"
      ? PERSONAS.filter((p) => p.senderId === "coach")
      : body.persona
      ? PERSONAS.filter((p) => p.senderId === body.persona)
      : PERSONAS;

    const results: Record<string, string> = {};
    for (const persona of targets) {
      results[persona.senderId] = await callOpenRouter(
        persona,
        body.message,
        body.scenario,
        userId,
        { context: body.context, mode: body.mode },
      );
    }

    return json({ ...results, remaining: rpc?.remaining ?? 0 }, 200, headers);
  } catch (e) {
    if (e instanceof ApiUpstreamError) {
      return json({ error: e.code }, e.status, headers);
    }
    return json({ error: "INTERNAL_ERROR" }, 503, headers);
  }
});
