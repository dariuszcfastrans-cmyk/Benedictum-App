// Wspólne moduły hosta (KROK 7) — CORS / JSON / sanitacja błędów / JWT-userId / walidacja body.
// Wydzielone z legacy openrouter-proxy 1:1 (parity) dla thin hosta llm-gateway.
// Legacy proxy (gemini-proxy, openrouter-proxy) usunięte w KROKU 8 — llm-gateway jedynym hostem LLM.
import { PERSONAS } from "./prompts/index.ts";

/// Czyta CORS_ORIGINS leniwie (przy wywołaniu, nie przy imporcie) — sam import hosta
/// nie wymaga uprawnień env (brama importowa działa z --allow-read).
function readCorsOrigins(): string[] {
  const raw = Deno.env.get("CORS_ORIGINS") ??
    "http://localhost:8899,http://localhost:3000";
  return raw.split(",").map((s) => s.trim()).filter((s) => s.length > 0);
}

export function corsResponse() {
  return {
    "Access-Control-Allow-Origin": readCorsOrigins().join(", "),
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };
}

export function json(data: unknown, status = 200, headers: HeadersInit = {}): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...headers },
  });
}

/// Sanitacja wiadomości błędu: maskowanie kluczy (gemini/sk-), JWT i cięcie >200 znaków.
export function safeErrorMessage(e: unknown): string {
  const msg = e instanceof Error ? e.message : String(e);
  const sanitized = msg
    .replace(/AIza[0-9A-Za-z_\-]{35}/g, "[REDACTED]")
    .replace(/sk-[A-Za-z0-9_\-]{20,}/g, "[REDACTED]")
    .replace(/eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+/g, "[REDACTED]");
  return sanitized.length > 200 ? sanitized.slice(0, 200) + "..." : sanitized;
}

/// Wyciąga `sub` (userId) z payloadu Bearer tokena JWT. Podpis weryfikuje platforma
/// Supabase (verify_jwt) PRZED kodem funkcji — tu tylko dekodowanie bez krypto (parity).
export function decodeJwtUserId(authHeader: string): string | null {
  if (!authHeader.startsWith("Bearer ")) return null;
  const token = authHeader.slice("Bearer ".length);
  const payloadPart = token.split(".")[1];
  if (!payloadPart) return null;
  try {
    const decoded = JSON.parse(atob(payloadPart));
    return typeof decoded.sub === "string" ? decoded.sub : null;
  } catch {
    return null;
  }
}

/// Błąd aplikacyjny hosta (walidacja body / konfiguracja) — sanitarne kody dla klienta.
export class ApiUpstreamError extends Error {
  status: number;
  code: string;
  retryAfterSeconds?: number;
  constructor(status: number, code: string, retryAfterSeconds?: number) {
    super(code);
    this.name = "ApiUpstreamError";
    this.status = status;
    this.code = code;
    this.retryAfterSeconds = retryAfterSeconds;
  }
}

/// Walidowane body dla trybów rozmowy (intake/analyze).
export type ChatBody = {
  mode: "intake" | "analyze";
  persona?: string;
  message: string;
  scenario: string;
  context?: string;
};

/// Walidowane body dla trybu raportu (mode:"report").
export type ReportBody = {
  mode: "report";
  scenario: string;
  context: string;
};

/// Walidacja body żądania LLM (parity z openrouter-proxy 1:1).
export function validateBody(body: unknown): ChatBody | ReportBody {
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