// Adapter OpenRouter (KROK 4) — czysty tłumacz Core → payload OpenRouter i odpowiedź → Core.
// Typowany TS. BEZ fetch — transport w engine (KROK 5).
// Parity z legacy openrouter-proxy (1:1, usunięty w KROKU 8): payload (messages, temperature, max_tokens,
// reasoning:{enabled:false}, user) i parsowanie content (string | tablica części).
import { CanonicalError, type TaskSpec, parseReport } from "../core/index.ts";
import { PERSONAS, renderReportPrompt, renderSystemPrompt } from "../prompts/index.ts";
import {
  type LlmAdapter,
  type ProviderAuth,
  type ProviderErrorContext,
  type ProviderParseResult,
  type ProviderRequest,
} from "./types.ts";

const OPENROUTER_PATH = "/api/v1/chat/completions";
const OPENROUTER_BASE_URL = "https://openrouter.ai";
const OPENROUTER_REPORT_USER_TEXT = "Wygeneruj raport końcowy sesji.";

/// Rozwiązanie persony: intake → zawsze "coach"; analyze → task.persona (wymagana).
function resolvePersona(task: TaskSpec) {
  const mode = task.mode ?? "analyze";
  const personaId = mode === "intake" ? "coach" : task.persona;
  const persona = PERSONAS.find((p) => p.senderId === personaId);
  if (!persona) {
    throw new TypeError(`openrouterAdapter: nieznana persona '${personaId}' (mode=${mode})`);
  }
  return persona;
}

function messagesFor(task: TaskSpec): Array<{ role: string; content: string }> {
  if (task.kind === "report") {
    return [
      { role: "system", content: renderReportPrompt(task.scenario, task.context ?? "") },
      { role: "user", content: OPENROUTER_REPORT_USER_TEXT },
    ];
  }
  if (typeof task.message !== "string" || task.message.trim().length === 0) {
    throw new TypeError("openrouterAdapter: message wymagany dla kind=chat");
  }
  const persona = resolvePersona(task);
  return [
    {
      role: "system",
      content: renderSystemPrompt(persona, task.scenario, task.message, {
        context: task.context,
        mode: task.mode,
      }),
    },
    { role: "user", content: task.message },
  ];
}

export const openrouterAdapter: LlmAdapter = {
  providerId: "openrouter",
  baseUrl: OPENROUTER_BASE_URL,

  buildRequest(task: TaskSpec, model: string, auth: ProviderAuth): ProviderRequest {
    return {
      method: "POST",
      path: OPENROUTER_PATH,
      query: {},
      headers: {
        Authorization: `Bearer ${auth.apiKey}`,
        "Content-Type": "application/json",
      },
      body: {
        model,
        messages: messagesFor(task),
        temperature: task.temperature,
        max_tokens: task.maxTokens,
        reasoning: { enabled: false },
        user: task.userId,
        provider: { data_collection: "deny" },
      },
    };
  },

  parseResponse(body: unknown, task: TaskSpec): ProviderParseResult {
    const data = body as { choices?: Array<{ message?: { content?: unknown } }> } | null;
    const content = data?.choices?.[0]?.message?.content;
    const text = typeof content === "string"
      ? content.trim()
      : Array.isArray(content)
      ? content
        .map((p: unknown) =>
          typeof p === "object" && p !== null && "text" in p
            ? String((p as Record<string, unknown>).text ?? "")
            : ""
        )
        .join("\n")
        .trim()
      : "";
    if (!text) return { ok: false, reason: "empty" };
    if (task.kind === "report") {
      const report = parseReport(text);
      if (!report) return { ok: false, reason: "invalid" };
      return { ok: true, value: { kind: "report", report } };
    }
    return { ok: true, value: { kind: "chat", text } };
  },

  // Parity z openrouter-proxy: 429 → RATE_LIMITED (Retry-After); 404 → MODEL_OR_POLICY_BLOCKED;
  // 400/401/402/403 → QUOTA_EXHAUSTED (banda CREDENTIALS_OR_QUOTA z proxy — zblokowana do
  // najbliższego kodu kanonicznego); reszta → UPSTREAM_ERROR. Model w providerDetail (jak proxy).
  mapError(
    status: number,
    retryAfterSeconds: number | undefined,
    ctx: ProviderErrorContext,
  ): CanonicalError {
    if (status === 429) {
      return new CanonicalError({ code: "RATE_LIMITED", retryAfterSeconds });
    }
    if (status === 404) {
      return new CanonicalError({ code: "MODEL_OR_POLICY_BLOCKED", providerDetail: ctx.model });
    }
    if ([400, 401, 402, 403].includes(status)) {
      return new CanonicalError({ code: "QUOTA_EXHAUSTED", providerDetail: ctx.model });
    }
    return new CanonicalError({ code: "UPSTREAM_ERROR", providerDetail: ctx.model });
  },
};