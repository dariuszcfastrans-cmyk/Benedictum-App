// Engine LLM (KROK 5) — transport + C-0 fallback wg kontraktu:
//  - adaptery są czystymi tłumaczami (buildRequest/parseResponse/mapError) — engine WYKONUJE transport,
//  - selekcja tracków po zdolnościach (task.capabilities ⊆ track.capabilities), required pierwsze,
//  - w tracku: router wybiera modele; pętla modeli z C-0 (EMPTY_RESPONSE / INVALID_REPORT → next),
//    błędy HTTP → mapError adaptera (parity z proxy), ostatni błąd wygrywa,
//  - zero silent defaults: brak tracków / brak zdolności / brak sekretu / brak adaptera → NOT_CONFIGURED;
//    brak modeli → NO_MODELS. Retry-After tylko nośnik w błędzie (parity z proxy: brak sleepu).
import {
  CanonicalError,
  type ExecutionTrack,
  type TaskSpec,
  type TrackPolicy,
  type TrackRouter,
} from "../core/index.ts";
import { extractRetryAfter } from "../backoff.ts";
import {
  type LlmAdapter,
  type ProviderRequest,
  type ProviderResult,
} from "../adapters/types.ts";
import { StaticOrderRouter } from "./router.ts";
import { resolveCarrierKey } from "./registry.ts";
import { CapabilityPolicy } from "./policies.ts";

/// Transport (wstrzykiwany dla testów; default = fetch). Buduje pełny URL: baseUrl + path + query.
/// KROK 6 (E4): opcjonalny `signal` — AbortSignal dla timeoutu pojedynczego żądania.
export type Transport = (
  req: ProviderRequest,
  baseUrl: string,
  signal?: AbortSignal,
) => Promise<Response>;

export const fetchTransport: Transport = async (req, baseUrl, signal) => {
  const url = new URL(req.path, baseUrl);
  for (const [k, v] of Object.entries(req.query)) {
    url.searchParams.set(k, v);
  }
  return fetch(url, {
    method: req.method,
    headers: req.headers,
    body: JSON.stringify(req.body),
    signal,
  });
};

/// Kontrakt silnika (KROK 6 — REPLACEABLE ENGINE): wymienność implementacji bez zmiany
/// konsumentów. Jedyna impl na dziś: `Engine` (sekwencyjny, unary). FUTURE: hedged/queued/realtime.
export interface IExecutionEngine {
  execute(task: TaskSpec, tracks: ExecutionTrack[], env: EngineEnv): Promise<ProviderResult>;
}

/// Budżet wykonania (KROK 6, opt-in — domyślnie bez limitów, parity z proxy).
export type EngineBudget = {
  /// Maksymalna liczba prób (wywołań modeli) na jedno execute(); 0/brak = bez limitu.
  maxAttempts?: number;
  /// Twardy limit czasu całego execute() w ms; sprawdzany między próbami. Brak = bez limitu.
  deadlineMs?: number;
};

export type EngineDeps = {
  /// providerId → adapter (klucze tracków `provider`; brak adaptera = konfiguracja → NOT_CONFIGURED).
  adapters: Record<string, LlmAdapter>;
  router?: TrackRouter;
  transport?: Transport;
  /// Łańcuch polityk kwalifikacji tracków (KROK 6). Domyślnie [CapabilityPolicy] (parity D/19);
  /// rozszerzenie łańcucha (np. DataPolicy) w composition root — bez zmian w engine/core.
  policies?: TrackPolicy[];
  /// R3 (KROK 6): czy `task.userId` trafia do upstreamu. Domyślnie true (obecne zachowanie, parity).
  forwardUserId?: boolean;
  /// Budżet per execute() (opt-in; domyślnie brak — parity z proxy).
  budget?: EngineBudget;
  /// Timeout pojedynczego żądania w ms (E4 — AbortSignal). Opt-in; domyślnie brak (parity).
  requestTimeoutMs?: number;
};

/// Środowisko wykonania engine — sekrety nośnika tracków (default w bramie/gateway: Deno.env.get).
export type EngineEnv = {
  getSecret(name: string): string | undefined;
};

export class Engine implements IExecutionEngine {
  readonly adapters: Record<string, LlmAdapter>;
  readonly router: TrackRouter;
  readonly transport: Transport;
  readonly policies: TrackPolicy[];
  readonly forwardUserId: boolean;
  readonly budget: EngineBudget;
  readonly requestTimeoutMs: number | undefined;

  constructor(deps: EngineDeps) {
    this.adapters = deps.adapters;
    this.router = deps.router ?? new StaticOrderRouter();
    this.transport = deps.transport ?? fetchTransport;
    this.policies = deps.policies ?? [new CapabilityPolicy()];
    this.forwardUserId = deps.forwardUserId ?? true;
    this.budget = deps.budget ?? {};
    this.requestTimeoutMs = deps.requestTimeoutMs;
  }

  /// Wykonuje zadanie: pierwszy sukces (kontrakt spełniony) wygrywa; błąd C-0 / HTTP →
  /// kolejny model, potem kolejny track; po wyczerpaniu — ostatni błąd (albo NO_MODELS).
  async execute(task: TaskSpec, tracks: ExecutionTrack[], env: EngineEnv): Promise<ProviderResult> {
    if (tracks.length === 0) {
      throw new CanonicalError({ code: "NOT_CONFIGURED" });
    }
    // KROK 6: kwalifikacja przez łańcuch polityk (domyślnie CapabilityPolicy — parity z D/19).
    let policyReason: string | undefined;
    const matching = tracks.filter((t) => {
      for (const policy of this.policies) {
        const result = policy.qualify(t, task);
        if (!result.ok) {
          policyReason ??= `${policy.id}:${result.reason ?? "rejected"}`;
          return false;
        }
      }
      return true;
    });
    if (matching.length === 0) {
      throw new CanonicalError({ code: "NOT_CONFIGURED", providerDetail: policyReason });
    }
    const ordered = [...matching].sort((a, b) => Number(b.required) - Number(a.required));

    // KROK 6: budżet per execute() (opcjonalny). `attempts` = liczba prób (wywołań modeli).
    const startedAt = Date.now();
    const deadline = this.budget.deadlineMs === undefined
      ? undefined
      : startedAt + this.budget.deadlineMs;
    const deadlineHit = () => deadline !== undefined && Date.now() >= deadline;
    let attempts = 0;
    let budgetHit = false;

    // R3 (KROK 6): polityka przekazania userId — strip na kopii taska (bez mutacji wejścia).
    const effectiveTask = this.forwardUserId === false && task.userId !== undefined
      ? { ...task, userId: undefined }
      : task;

    let lastError: CanonicalError | null = null;
    for (const track of ordered) {
      const adapter = this.adapters[track.provider];
      if (!adapter) {
        throw new CanonicalError({ code: "NOT_CONFIGURED", providerDetail: `adapter:${track.provider}` });
      }
      // Wąskie: na dziś jedyny nośnik to secret-json (database = FUTURE, D6).
      if (track.carrier.kind !== "secret-json") {
        throw new CanonicalError({ code: "NOT_CONFIGURED", providerDetail: `carrier:${track.carrier.kind}` });
      }
      const secretRaw = env.getSecret(track.carrier.secretName);
      if (!secretRaw) {
        throw new CanonicalError({ code: "NOT_CONFIGURED", providerDetail: `secret:${track.carrier.secretName}` });
      }
      let apiKey: string;
      try {
        apiKey = resolveCarrierKey(secretRaw);
      } catch {
        throw new CanonicalError({ code: "NOT_CONFIGURED", providerDetail: `secret:${track.carrier.secretName}` });
      }
      const models = this.router.select(track, task);
      if (models.length === 0) {
        lastError = new CanonicalError({ code: "NO_MODELS" });
        continue;
      }
      for (const model of models) {
        if (this.budget.maxAttempts !== undefined && attempts >= this.budget.maxAttempts) {
          lastError = new CanonicalError({ code: "UPSTREAM_ERROR", providerDetail: "budget:maxAttempts" });
          budgetHit = true;
          break;
        }
        if (deadlineHit()) {
          lastError = new CanonicalError({ code: "UPSTREAM_ERROR", providerDetail: "budget:deadline" });
          budgetHit = true;
          break;
        }
        attempts++;
        const req = adapter.buildRequest(effectiveTask, model, { apiKey });
        let res: Response;
        try {
          res = await this.requestWithTimeout(req, adapter.baseUrl);
        } catch (err) {
          // E4 (KROK 6): przekroczenie timeoutu żądania → AbortError → canonical, C-0 do następnego.
          if (err instanceof Error && err.name === "AbortError") {
            lastError = new CanonicalError({ code: "UPSTREAM_ERROR", providerDetail: `${model}:timeout` });
            continue;
          }
          throw err;
        }
        if (res.ok) {
          let body: unknown = null;
          try {
            body = await res.json();
          } catch {
            // Niepoprawny JSON przy 200 = naruszenie kontraktu → C-0 (INVALID_REPORT dla report,
            // EMPTY_RESPONSE dla chat — parsowanie adaptera zwróci reason; null → "empty").
          }
          const parsed = adapter.parseResponse(body, task);
          if (parsed.ok) return parsed.value;
          lastError = new CanonicalError({
            code: parsed.reason === "empty" ? "EMPTY_RESPONSE" : "INVALID_REPORT",
          });
          continue;
        }
        lastError = adapter.mapError(res.status, extractRetryAfter(res), { model });
        continue;
      }
      if (budgetHit) break;
    }
    throw lastError ?? new CanonicalError({ code: "NO_MODELS" });
  }

  /// Wykonanie żądania z opcjonalnym timeoutem (E4): AbortController + timer na całe żądanie.
  private requestWithTimeout(req: ProviderRequest, baseUrl: string): Promise<Response> {
    if (this.requestTimeoutMs === undefined) return this.transport(req, baseUrl);
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.requestTimeoutMs);
    return this.transport(req, baseUrl, controller.signal).finally(() => clearTimeout(timer));
  }
}