// Adaptery LLM (KROK 4) — czyste tłumacze: Core → payload providera i odpowiedź → Core.
// BEZ fetch, BEZ transportu, BEZ zależności zewnętrznych (transport w engine — KROK 5).
import { type CanonicalError, type ReportContract, type TaskSpec } from "../core/index.ts";

/// Poświadczenie providera — dostarcza engine z konfiguracji tracka (secrets).
export type ProviderAuth = {
  apiKey: string;
};

/// Gotowy opis żądania: buduje ADAPTER (tłumaczenie), wykonuje ENGINE (transport).
export type ProviderRequest = {
  method: "POST";
  /// Ścieżka względna (engine dokleja base URL z konfiguracji tracka).
  path: string;
  /// Parametry zapytania (np. Gemini `?key=…`).
  query: Record<string, string>;
  headers: Record<string, string>;
  /// Ciało żądania — serializowalne (JSON).
  body: unknown;
};

/// Wynik tłumaczenia odpowiedzi providera (wg rodzaju zadania).
export type ProviderResult =
  | { kind: "chat"; text: string }
  | { kind: "report"; report: ReportContract };

/// Wynik parsowania z rozróżnieniem pustej treści vs. niepoprawnego kontraktu.
/// Engine mapuje: empty → EMPTY_RESPONSE, invalid → INVALID_REPORT (C-0 → próba następnego modelu).
export type ProviderParseResult =
  | { ok: true; value: ProviderResult }
  | { ok: false; reason: "empty" | "invalid" };

/// Kontekst błędu providera (model, na którym wystąpił błąd).
export type ProviderErrorContext = {
  model: string;
};

/// Kontrakt adaptera LLM — czysty tłumacz (bez fetch/transportu; transport w engine).
/// KROK 5 (D/18): `baseUrl` (stała providera) i `mapError` (status → CanonicalError,
/// parity z obecnymi proxy — patrz core: „mapowanie błędów providerów należy do adapterów").
export interface LlmAdapter {
  readonly providerId: string;
  readonly baseUrl: string;
  buildRequest(task: TaskSpec, model: string, auth: ProviderAuth): ProviderRequest;
  parseResponse(body: unknown, task: TaskSpec): ProviderParseResult;
  mapError(
    status: number,
    retryAfterSeconds: number | undefined,
    ctx: ProviderErrorContext,
  ): CanonicalError;
}