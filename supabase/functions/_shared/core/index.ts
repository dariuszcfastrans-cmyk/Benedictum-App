// LLM Foundation — Core types v1.1 (KROK 3) + rozszerzenia KROKU 4 (TaskSpec.mode/userId,
// parseReport jako kanon walidacji kontraktu). Czysty moduł: TYLKO typy + czyste funkcje —
// bez I/O, bez sieci, bez importów zewnętrznych.
// Zakres wg decyzji Operatora (D8, 2026-08-18): Part/Content, CanonicalError, ExecutionTrack,
// TaskSpec, CapabilityId, kontrakty (ReportContract), ArtifactRef, deklaracja IArtifactStore.
// Streaming / orchestration / implementacja ArtifactStore: świadomie FUTURE (J.5/J.6) — typy
// zaprojektowane tak, by rozbudowa (nowe Part, nowe CapabilityId, nowe tracki) nie wymagała
// przebudowy core (J.5). Zero silent defaults (J.4): fabryki wymagają jawnych parametrów,
// walidatory odrzucają niekompletne struktury.

/// Identyfikatory zdolności (multimodalność: typy teraz, implementacje FUTURE — J.6).
export type CapabilityId = "text" | "vision" | "image" | "audio";

/// Część wiadomości (Part) — unia rozszerzalna (FUTURE: video, file).
export type Part =
  | { kind: "text"; text: string }
  | { kind: "image"; dataUrl: string; mimeType?: string };

export function textPart(text: string): Part {
  if (typeof text !== "string" || text.trim().length === 0) {
    throw new TypeError("textPart: text wymagany (zero silent defaults)");
  }
  return { kind: "text", text };
}

export function imagePart(dataUrl: string, mimeType?: string): Part {
  if (typeof dataUrl !== "string" || dataUrl.length === 0) {
    throw new TypeError("imagePart: dataUrl wymagany (zero silent defaults)");
  }
  return { kind: "image", dataUrl, mimeType };
}

/// Treść wiadomości (Content) — rola + części.
export type Content = {
  role: "system" | "user" | "assistant";
  parts: Part[];
};

/// Kanoniczne kody błędów — język warstwy engine. Mapowanie błędów providerów → CanonicalError
/// należy do adapterów (KROK 4). CanonicalError jest nośnikowo-niezależny i sanitarny.
export type CanonicalErrorCode =
  | "EMPTY_RESPONSE"
  | "INVALID_REPORT"
  | "RATE_LIMITED"
  | "QUOTA_EXHAUSTED"
  | "NOT_CONFIGURED"
  | "UPSTREAM_ERROR"
  | "NO_MODELS"
  | "MODEL_OR_POLICY_BLOCKED";

function defaultStatusFor(code: CanonicalErrorCode): number {
  switch (code) {
    case "EMPTY_RESPONSE":
    case "INVALID_REPORT":
      return 422;
    case "RATE_LIMITED":
      return 429;
    default:
      return 503;
  }
}

/// Kanoniczny błąd LLM — sanitarny (bez sekretów/ścieżek); szczegóły providera tylko w logach.
export class CanonicalError extends Error {
  readonly code: CanonicalErrorCode;
  readonly status: number;
  readonly retryAfterSeconds?: number;
  readonly providerDetail?: string;

  constructor(opts: {
    code: CanonicalErrorCode;
    status?: number;
    retryAfterSeconds?: number;
    providerDetail?: string;
  }) {
    super(opts.code);
    this.name = "CanonicalError";
    this.code = opts.code;
    this.status = opts.status ?? defaultStatusFor(opts.code);
    this.retryAfterSeconds = opts.retryAfterSeconds;
    this.providerDetail = opts.providerDetail;
  }
}

/// Rodzaje zadań LLM.
export type TaskKind = "chat" | "report";

/// Specyfikacja zadania LLM — opisywana jawnie (zero silent defaults).
export type TaskSpec = {
  kind: TaskKind;
  scenario: string;
  context?: string;
  persona?: string;
  message?: string;
  /// Tryb rozmowy (tylko chat): "intake" (Coach-wywiad) | "analyze" (domyślny).
  mode?: "intake" | "analyze";
  /// Kontekst żądania (R3): identyfikator użytkownika dla providera/upstreamu.
  /// Na dziś nośnik w TaskSpec; docelowo (engine/gateway) kontekst żądania oddzielony.
  userId?: string;
  capabilities: CapabilityId[];
  maxTokens: number;
  temperature: number;
};

export function createTaskSpec(spec: TaskSpec): TaskSpec {
  if (typeof spec.scenario !== "string" || spec.scenario.trim().length === 0) {
    throw new TypeError("createTaskSpec: scenario wymagany (zero silent defaults)");
  }
  if (!Number.isInteger(spec.maxTokens) || spec.maxTokens <= 0) {
    throw new TypeError("createTaskSpec: maxTokens musi być dodatnią liczbą całkowitą");
  }
  if (typeof spec.temperature !== "number" || spec.temperature < 0 || spec.temperature > 2) {
    throw new TypeError("createTaskSpec: temperature w zakresie [0, 2]");
  }
  if (spec.mode !== undefined && spec.mode !== "intake" && spec.mode !== "analyze") {
    throw new TypeError("createTaskSpec: mode musi być 'intake' | 'analyze'");
  }
  if (
    spec.kind === "chat" &&
    (typeof spec.message !== "string" || spec.message.trim().length === 0)
  ) {
    throw new TypeError("createTaskSpec: message wymagany dla kind=chat");
  }
  return { ...spec, scenario: spec.scenario.trim() };
}

/// Identyfikator tracka wykonania.
export type TrackId = string;

/// Nośnik konfiguracji tracka (D6): teraz JSON-secret; tabela FUTURE (deklaracja).
export type CarrierRef =
  | { kind: "secret-json"; secretName: string }
  | { kind: "database"; table: string; key: string };

/// Deklaracja polityki danych (KROK 6 — minimalna oś Supplier/Route).
/// Aktywne deklaracje (walidowane w validateExecutionTrack), PUSTA egzekucja —
/// egzekwowanie (blokada regionu/treningu) to FUTURE (plan KROKU 6).
/// Podstawa Data Safety: region jurysdykcji, zgoda na trening, retencja.
export type DataPolicyDeclaration = {
  /// Jurysdykcja przetwarzania (np. "eu", "us", "cn") — deklaracja dla Data Safety.
  region?: string;
  /// Czy dostawca może trenować na danych (deklaracja; brak = nieznane).
  training?: boolean;
  /// Retencja danych w dniach (deklaracja; brak = nieznane).
  retentionDays?: number;
};

/// Track wykonania — nośnikowo-niezależny kontrakt (D6).
/// `provider` (D/17, KROK 5): klucz do mapy adapterów engine — jawne, zero silent defaults.
/// `dataPolicy` (KROK 6): deklaracja polityki danych (region/trening/retencja) — additive (J.5).
export type ExecutionTrack = {
  id: TrackId;
  name: string;
  description: string;
  provider: string;
  carrier: CarrierRef;
  models: string[];
  capabilities: CapabilityId[];
  required: boolean;
  dataPolicy?: DataPolicyDeclaration;
};

export function validateExecutionTrack(track: ExecutionTrack): ExecutionTrack {
  if (typeof track.id !== "string" || track.id.trim().length === 0) {
    throw new TypeError("validateExecutionTrack: id wymagany");
  }
  if (typeof track.provider !== "string" || track.provider.trim().length === 0) {
    throw new TypeError("validateExecutionTrack: provider wymagany (zero silent defaults)");
  }
  if (!Array.isArray(track.models) || track.models.length === 0) {
    throw new TypeError("validateExecutionTrack: models nie może być puste");
  }
  if (!Array.isArray(track.capabilities) || track.capabilities.length === 0) {
    throw new TypeError("validateExecutionTrack: capabilities nie może być puste");
  }
  if (track.carrier?.kind !== "secret-json") {
    throw new TypeError("validateExecutionTrack: jedyny obsługiwany nośnik to secret-json (database = FUTURE)");
  }
  // KROK 6: deklaracja polityki danych — walidacja kształtu (aktywne deklaracje, pusta egzekucja).
  if (track.dataPolicy !== undefined) {
    const dp = track.dataPolicy;
    if (dp.region !== undefined && (typeof dp.region !== "string" || dp.region.trim().length === 0)) {
      throw new TypeError("validateExecutionTrack: dataPolicy.region musi być niepustym stringiem");
    }
    if (dp.training !== undefined && typeof dp.training !== "boolean") {
      throw new TypeError("validateExecutionTrack: dataPolicy.training musi być booleanem");
    }
    if (
      dp.retentionDays !== undefined &&
      (!Number.isInteger(dp.retentionDays) || dp.retentionDays <= 0)
    ) {
      throw new TypeError("validateExecutionTrack: dataPolicy.retentionDays musi być dodatnią liczbą całkowitą");
    }
  }
  return track;
}

/// Router tracków — LEKKI kontrakt (decyzja Operatora: wariant A, bez warstwy routera).
/// Jedyna implementacja na dziś: StaticOrderRouter (KROK 5). FUTURE: health/cost/canary.
export interface TrackRouter {
  select(track: ExecutionTrack, task: TaskSpec): string[];
}

/// Wynik kwalifikacji tracka przez politykę (KROK 6).
export type PolicyResult = { ok: boolean; reason?: string };

/// Polityka tracka — decydent kwalifikacji (KROK 6). Kontrakt w core (precedens: TrackRouter,
/// D/11); implementacje (CapabilityPolicy, DataPolicy) w `_shared/engine/policies.ts` — czyste,
/// bez wiedzy o adapterach/HTTP. Engine wykonuje łańcuch polityk (domyślnie CapabilityPolicy).
export interface TrackPolicy {
  readonly id: string;
  qualify(track: ExecutionTrack, task: TaskSpec): PolicyResult;
}

/// Rodzaje artefaktów (magazyn artefaktów: deklaracja teraz, implementacja FUTURE — J.6).
export type ArtifactKind = "report" | "conversation" | "image";

/// Referencja artefaktu — bez danych binarnych (dane w magazynie, osobna warstwa).
export type ArtifactRef = {
  id: string;
  kind: ArtifactKind;
  trackId: TrackId;
  mimeType: string;
  sizeBytes: number;
  sha256: string;
};

/// Deklaracja magazynu artefaktów — interfejs, implementacje FUTURE (J.5/J.6).
export interface IArtifactStore {
  put(ref: ArtifactRef, data: Uint8Array): Promise<void>;
  get(ref: ArtifactRef): Promise<Uint8Array>;
  exists(ref: ArtifactRef): Promise<boolean>;
}

/// Kontrakt raportu (Dyrektywa 2A §3) — kanon w core (D8 „kontrakty").
/// _shared/prompts re-eksportuje ten typ (brak dryfu).
export type ReportContract = {
  strengths: string[];
  gaps: string[];
  action_items: string[];
  overall_rating: number;
};

/// Walidacja odpowiedzi raportu (kanon — KROK 4; źródło historyczne: _shared/prompts).
/// Zwraca kontrakt albo null (422 INVALID_REPORT).
/// overall_rating musi być liczbą całkowitą 1–5; tablice — tablicami stringów.
export function parseReport(text: string): ReportContract | null {
  const trimmed = text.trim();
  if (!trimmed) return null;
  // Usuń ewentualne ramki markdown ```json ... ```.
  const json = trimmed.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "").trim();
  let data: unknown;
  try {
    data = JSON.parse(json);
  } catch {
    return null;
  }
  if (typeof data !== "object" || data === null || Array.isArray(data)) return null;
  const obj = data as Record<string, unknown>;
  if (!Array.isArray(obj.strengths) || !obj.strengths.every((s) => typeof s === "string")) {
    return null;
  }
  if (!Array.isArray(obj.gaps) || !obj.gaps.every((s) => typeof s === "string")) {
    return null;
  }
  if (!Array.isArray(obj.action_items) || !obj.action_items.every((s) => typeof s === "string")) {
    return null;
  }
  const rating = obj.overall_rating;
  if (typeof rating !== "number" || !Number.isInteger(rating) || rating < 1 || rating > 5) {
    return null;
  }
  return {
    strengths: obj.strengths as string[],
    gaps: obj.gaps as string[],
    action_items: obj.action_items as string[],
    overall_rating: rating,
  };
}