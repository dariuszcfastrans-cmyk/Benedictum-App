// Engine (KROK 5) — wspólna powierzchnia importowa warstwy silnika.
export {
  Engine,
  fetchTransport,
  type EngineBudget,
  type EngineDeps,
  type EngineEnv,
  type IExecutionEngine,
  type Transport,
} from "./engine.ts";
export { StaticOrderRouter } from "./router.ts";
export { parseTracks, resolveCarrierKey } from "./registry.ts";
export { CapabilityPolicy, DataPolicy } from "./policies.ts";
export type { TrackPolicy, TrackRouter } from "../core/index.ts";