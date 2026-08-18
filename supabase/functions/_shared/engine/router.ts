// Router tracków — wariant A (decyzja Operatora; core deklaruje interfejs TrackRouter).
// Jedyna implementacja na dziś (KROK 5): kolejność statyczna — modele w kolejności listy tracka.
// FUTURE: strategie health/cost/canary jako nowe implementacje interfejsu (bez zmian w core).
import { type ExecutionTrack, type TaskSpec, type TrackRouter } from "../core/index.ts";

export class StaticOrderRouter implements TrackRouter {
  select(track: ExecutionTrack, _task: TaskSpec): string[] {
    // Kopia listy — kolejność i zawartość z tracka (validateExecutionTrack gwarantuje niepustą listę).
    return [...track.models];
  }
}