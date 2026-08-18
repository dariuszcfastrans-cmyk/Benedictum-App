// Polityki tracków (KROK 6) — czyste, wymienialne mechanizmy kwalifikacji.
// Kontrakt w core (TrackPolicy); polityki NIE znają adapterów ani HTTP (czystość — brama K6).
// Engine wykonuje łańcuch polityk; domyślny łańcuch = [CapabilityPolicy] (parity z D/19).
// FUTURE (nie w KROKU 6): HealthPolicy, CostPolicy, egzekucja DataPolicy (region/trening).
import { type ExecutionTrack, type TaskSpec, type TrackPolicy } from "../core/index.ts";

/// Kwalifikacja po zdolnościach: task.capabilities ⊆ track.capabilities.
/// Formalizacja selekcji wbudowanej w engine (D/19) — wymienialna bez zmian w engine/core.
export class CapabilityPolicy implements TrackPolicy {
  readonly id = "capability";

  qualify(track: ExecutionTrack, task: TaskSpec) {
    const missing = task.capabilities.filter((c) => !track.capabilities.includes(c));
    return missing.length === 0
      ? { ok: true }
      : { ok: false, reason: `requires:${missing.join(",")}` };
  }
}

/// Polityka danych (minimalna oś Supplier/Route, KROK 6).
/// Aktywne deklaracje (region/training/retentionDays) — walidowane w validateExecutionTrack;
/// PUSTA egzekucja: egzekwowanie (blokada regionu/treningu) to FUTURE (plan KROKU 6).
/// Obecność polityki w łańcuchu czyni oś wymienialną bez zmian w engine/core.
export class DataPolicy implements TrackPolicy {
  readonly id = "data";

  qualify(_track: ExecutionTrack, _task: TaskSpec) {
    return { ok: true };
  }
}
