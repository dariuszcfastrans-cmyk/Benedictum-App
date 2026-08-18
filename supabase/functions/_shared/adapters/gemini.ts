// Adapter Gemini (KROK 4) — czysty tłumacz Core → payload Gemini i odpowiedź → Core.
// Typowany TS (F0 domknięty: nowy kod, NIE odtworzenie transpilowanego gemini-proxy/index.ts).
// BEZ fetch — transport w engine (KROK 5).
// Parity z legacy gemini-proxy (1:1, usunięty w KROKU 8): struktura payloadów
// (system_instruction, contents, generationConfig z thinkingConfig:{thinkingBudget:0} — BS-3)
// i parsowanie treści (candidates[0].content.parts → text; pusty → empty; raport niepoprawny → invalid).
import { CanonicalError, type TaskSpec, parseReport } from "../core/index.ts";
import { PERSONAS, renderReportPrompt, renderSystemPrompt } from "../prompts/index.ts";
import {
  type LlmAdapter,
  type ProviderAuth,
  type ProviderErrorContext,
  type ProviderParseResult,
  type ProviderRequest,
} from "./types.ts";

const GEMINI_REPORT_USER_TEXT = "Wygeneruj raport końcowy sesji.";
const GEMINI_BASE_URL = "https://generativelanguage.googleapis.com";

function pathFor(model: string): string {
  return `/v1beta/models/${model}:generateContent`;
}

/// Rozwiązanie persony: intake → zawsze "coach"; analyze → task.persona (wymagana).
function resolvePersona(task: TaskSpec) {
  const mode = task.mode ?? "analyze";
  const personaId = mode === "intake" ? "coach" : task.persona;
  const persona = PERSONAS.find((p) => p.senderId === personaId);
  if (!persona) {
    throw new TypeError(`geminiAdapter: nieznana persona '${personaId}' (mode=${mode})`);
  }
  return persona;
}

function buildGeminiBody(systemText: string, userText: string, task: TaskSpec): unknown {
  return {
    system_instruction: { parts: [{ text: systemText }] },
    contents: [{ role: "user", parts: [{ text: userText }] }],
    generationConfig: {
      temperature: task.temperature,
      maxOutputTokens: task.maxTokens,
      thinkingConfig: { thinkingBudget: 0 },
    },
  };
}

export const geminiAdapter: LlmAdapter = {
  providerId: "gemini",
  baseUrl: GEMINI_BASE_URL,

  buildRequest(task: TaskSpec, model: string, auth: ProviderAuth): ProviderRequest {
    if (task.kind === "report") {
      const systemText = renderReportPrompt(task.scenario, task.context ?? "");
      return {
        method: "POST",
        path: pathFor(model),
        query: { key: auth.apiKey },
        headers: { "Content-Type": "application/json" },
        body: buildGeminiBody(systemText, GEMINI_REPORT_USER_TEXT, task),
      };
    }
    if (typeof task.message !== "string" || task.message.trim().length === 0) {
      throw new TypeError("geminiAdapter: message wymagany dla kind=chat");
    }
    const persona = resolvePersona(task);
    const systemText = renderSystemPrompt(persona, task.scenario, task.message, {
      context: task.context,
      mode: task.mode,
    });
    return {
      method: "POST",
      path: pathFor(model),
      query: { key: auth.apiKey },
      headers: { "Content-Type": "application/json" },
      body: buildGeminiBody(systemText, task.message, task),
    };
  },

  parseResponse(body: unknown, task: TaskSpec): ProviderParseResult {
    const data = body as
      | { candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }> }
      | null;
    const text = data?.candidates?.[0]?.content?.parts
      ?.map((p) => p.text ?? "")
      .join("\n")
      .trim() ?? "";
    if (!text) return { ok: false, reason: "empty" };
    if (task.kind === "report") {
      const report = parseReport(text);
      if (!report) return { ok: false, reason: "invalid" };
      return { ok: true, value: { kind: "report", report } };
    }
    return { ok: true, value: { kind: "chat", text } };
  },

  // Parity z gemini-proxy: 429 → RATE_LIMITED (Retry-After); 400/403 → QUOTA_EXHAUSTED;
  // reszta → UPSTREAM_ERROR. Bez szczegółów modelu (gemini-proxy nie włącza modelu w kod błędu).
  mapError(
    status: number,
    retryAfterSeconds: number | undefined,
    _ctx: ProviderErrorContext,
  ): CanonicalError {
    if (status === 429) {
      return new CanonicalError({ code: "RATE_LIMITED", retryAfterSeconds });
    }
    if (status === 400 || status === 403) {
      return new CanonicalError({ code: "QUOTA_EXHAUSTED" });
    }
    return new CanonicalError({ code: "UPSTREAM_ERROR" });
  },
};