// Rejestr tracków (KROK 5) — źródło tracków z JSON-secret (D6: secret-json teraz,
// database FUTURE). Zero silent defaults (J.4): każdy track walidowany przez
// validateExecutionTrack; sekret nośnika musi zawierać jawny `apiKey`.
import { type ExecutionTrack, validateExecutionTrack } from "../core/index.ts";

/// Parsuje LLM_TRACKS (JSON: tablica tracków). Pusta treść → [] (brak konfiguracji).
/// Niepoprawny JSON / nie-tablica / niekompletny track → TypeError (bez cichych domyślnych).
export function parseTracks(json: string): ExecutionTrack[] {
  const trimmed = json.trim();
  if (!trimmed) return [];
  let data: unknown;
  try {
    data = JSON.parse(trimmed);
  } catch {
    throw new TypeError("parseTracks: LLM_TRACKS to niepoprawny JSON");
  }
  if (!Array.isArray(data)) {
    throw new TypeError("parseTracks: LLM_TRACKS musi być tablicą tracków");
  }
  return data.map((entry) => validateExecutionTrack(entry));
}

/// Wyciąga `apiKey` z sekretu nośnika tracka (JSON obiekt). Brak/pusty → TypeError.
export function resolveCarrierKey(json: string): string {
  let data: unknown;
  try {
    data = JSON.parse(json);
  } catch {
    throw new TypeError("resolveCarrierKey: sekret tracka to niepoprawny JSON");
  }
  if (typeof data !== "object" || data === null || Array.isArray(data)) {
    throw new TypeError("resolveCarrierKey: sekret musi być obiektem JSON");
  }
  const apiKey = (data as Record<string, unknown>).apiKey;
  if (typeof apiKey !== "string" || apiKey.trim().length === 0) {
    throw new TypeError("resolveCarrierKey: apiKey wymagany (zero silent defaults)");
  }
  return apiKey;
}