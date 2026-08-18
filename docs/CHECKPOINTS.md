# CHECKPOINTS — rejestr kontrolny (LLM Foundation v2.0)

Statusy: OPEN / CLOSED / WAITING. Zatwierdzenie każdego checkpointa należy do Operatora.

## Checkpoint 1 — po KROKU 1 (C-0, BS-3, GEMINI_NOT_CONFIGURED)

Data: 2026-08-18.
Status: **CLOSED** (potwierdzony przez Operatora 2026-08-18; GO → KROK 2).

Dowody:
- `deno test --node-modules-dir=none --cached-only --allow-net --allow-env` na istniejących testach:
  **39 passed** (prompts 25 + backoff 7+7). (`session-proxy/session_proxy_test.ts` — błąd
  środowiskowy: brak `TEST_ANON_KEY`/`TEST_SERVICE_KEY` z `supabase status`; bez związku ze zmianą.)
- `fallback_regression_test.ts` (openrouter-proxy, type-check): **OK** —
  EMPTY_RESPONSE→next, INVALID_REPORT→next, wynik z 3. modelu; LLM=3, RPC=1.
- `fallback_regression_test.ts` (gemini-proxy, `--no-check`): **OK** — j.w.
- `git diff` (czysty, bez commita): gemini-proxy/index.ts +31/−10 (przyrost), openrouter-proxy/index.ts +24/−10.

Komendy uruchomieniowe testów regresyjnych (zapisane jako konwencja):
Harness to SCRIPT (top-level + `Deno.exit`), nie unit test: poprawna forma to `deno run`
(dla `deno test` runner nie kończy procesu po `Deno.exit(0)` — weryfikacja 2026-08-18).
```
deno run --node-modules-dir=none --cached-only --allow-net --allow-env supabase/functions/openrouter-proxy/fallback_regression_test.ts
deno run --no-check --node-modules-dir=none --cached-only --allow-net --allow-env supabase/functions/gemini-proxy/fallback_regression_test.ts
```

Zakres KROKU 1 objęty checkpointem:
- C-0 w 5 miejscach pętli (gemini: callGemini, callGeminiReport; openrouter: callOpenRouterReport,
  callOpenRouter, extractContent→null).
- BS-3: `thinkingConfig { thinkingBudget: 0 }` (2 payloady gemini).
- Fail-fast GEMINI_NOT_CONFIGURED (po JWT, przed RPC).
- Dokumentacja: ARC.md, DECISIONS_LOG.md, CHECKPOINTS.md.

Decyzja do potwierdzenia przez Operatora:
1. ~~Czy KROK 1 zamykamy i przechodzimy do KROKU 2~~ — POTWIERDZONE (2026-08-18).

## Checkpoint 2 — brama KROKU 2 (_shared/ extraction)

Data: 2026-08-18.
Status: **CLOSED** (wykonanie) — do potwierdzenia przez Operatora.

Zakres:
- `_shared/prompts/` (7 plików: index.ts + 5 szablonów + prompts_test.ts) — przeniesione z
  `gemini-proxy/prompts/`; SOURCE OF TRUTH (D1) pozostaje jeden.
- `_shared/backoff.ts` + `_shared/backoff_test.ts` — konsolidacja zdublowanych modułów obu proxy
  (logika była identyczna; usunięto gemini-proxy/backoff.ts, openrouter-proxy/backoff.ts,
  openrouter-proxy/backoff_test.ts, gemini-proxy/backoff_test.ts).
- Importy: gemini-proxy i openrouter-proxy → `../_shared/…` (koniec B1).
- Brama: `_shared/import_gate_test.ts` (API + statyczne sprawdzenie importów + brak starych ścieżek).

Dowody:
- `deno test --allow-read _shared/import_gate_test.ts _shared/prompts/prompts_test.ts _shared/backoff_test.ts`:
  **36 passed | 0 failed** (brama 4 + prompts 25 + backoff 7).
- Regresja po przeniesieniu (importy realnych modułów proxy działają):
  - openrouter-proxy/fallback_regression_test.ts (full type-check): **OK** (LLM=3, RPC=1);
  - gemini-proxy/fallback_regression_test.ts (--no-check): **OK** (LLM=3, RPC=1).
- `git status`: usunięcia starych ścieżek + nowe `_shared/` (bez commita).
- Bilans testów: dotychczasowe „39" = prompts 25 + backoff 7+7 → po konsolidacji prompts 25 +
  backoff 7 (jeden kanon) + brama 4 + regresja 2 (per proxy). Bez utraty pokrycia — 7 przypadków
  backoff identycznych w obu kopiach.

Decyzja do potwierdzenia przez Operatora:
1. ~~Czy brama KROKU 2 jest akceptowalna i przechodzimy do KROKU 3~~ — POTWIERDZONE (2026-08-18).

## Checkpoint 3 — po KROKU 3 (Core types v1.1)

Data: 2026-08-18.
Status: **CLOSED** (wykonanie) — do potwierdzenia przez Operatora.

Zakres:
- `_shared/core/index.ts` — czysty moduł (zero importów): Part/Content, CanonicalError,
  ExecutionTrack, TaskSpec, CapabilityId, ArtifactRef, IArtifactStore, TrackRouter (interfejs),
  ReportContract (kanon).
- `_shared/core/core_test.ts` — 5 testów runtime + użycie typów (type-check).
- Kanon kontraktu bez dryfu: prompts re-eksportuje `ReportContract` z core.
- Brama rozszerzona: czystość core (K3) + re-eksport kontraktu (K3).

Dowody:
- `deno test --allow-read _shared/core/core_test.ts _shared/import_gate_test.ts
  _shared/prompts/prompts_test.ts _shared/backoff_test.ts`: **43 passed | 0 failed**
  (core 5 + brama 6 + prompts 25 + backoff 7).
- Regresja po refaktorze kontraktu (bez zmian zachowania): openrouter-proxy **OK**,
  gemini-proxy **OK** (LLM=3, RPC=1).
- `git status`: nowe `_shared/core/`, zmiana `_shared/prompts/index.ts` (re-eksport),
  rozszerzenie bramy — bez commita.

Decyzja do potwierdzenia przez Operatora:
1. Czy core typy v1.1 są akceptowalne i przechodzimy do KROKU 4 (adaptery bez fetch;
   gemini-proxy jako nowy typowany adapter TS)?

## Checkpoint 4 — po KROKU 4 (adaptery LLM — czyste tłumacze)

Data: 2026-08-18.
Status: **CLOSED** (wykonanie) — do potwierdzenia przez Operatora.

Zakres:
- `_shared/core/index.ts`: TaskSpec + `mode?: "intake" | "analyze"` i `userId?: string`
  (additive, J.5 — bez przebudowy core); walidacja `mode` w `createTaskSpec`;
  `parseReport` przeniesiony do core (kanon walidacji kontraktu — D/10).
- `_shared/prompts/index.ts`: re-eksport `parseReport` z core (wsteczna zgodność — proxie
  nie zmieniają importów); usunięta definicja (koniec dryfu).
- `_shared/adapters/` — NOWA warstwa: `types.ts` (ProviderAuth, ProviderRequest, ProviderResult,
  ProviderParseResult, LlmAdapter), `gemini.ts` (`geminiAdapter`), `openrouter.ts`
  (`openrouterAdapter`), `adapters_test.ts`. Adaptery = CZYSTE tłumacze: zero `fetch`, zero
  `Deno.*`, zero jsr/npm (transport i secrets w engine — KROK 5).
- Parity 1:1 z obecnymi proxy: payloady (thinkingConfig:0 BS-3; reasoning:{enabled:false},
  user:task.userId), parsing (empty→"empty", raport niepoprawny→"invalid").
- Persona: intake → zawsze "coach"; analyze → task.persona (wymagana; TypeError inaczej).
- Brama rozszerzona: czystość adapterów (K4) + parseReport jako kanon w core (K4).

Dowody:
- `deno test --allow-read _shared/import_gate_test.ts _shared/core/core_test.ts
  _shared/adapters/adapters_test.ts _shared/prompts/prompts_test.ts _shared/backoff_test.ts`:
  **53 passed | 0 failed** (adaptery 6 + prompts 25 + core 7 + brama 8 + backoff 7).
- Regresja (bez zmian zachowania proxy; harness przez `deno run`):
  - openrouter-proxy **OK** (LLM=3, RPC=1);
  - gemini-proxy **OK** (LLM=3, RPC=1).
- `git status`: nowe `_shared/adapters/`, zmiany `_shared/core/` i `_shared/prompts/`,
  rozszerzenie bramy i core_test — bez commita.

Fakt operacyjny (nowa wiedza): harness regresyjny (top-level + `Deno.exit`) nie kończy
procesu pod `deno test`; poprawna forma `deno run` (komendy skorygowane w Checkpoint 1).

Decyzja do potwierdzenia przez Operatora:
1. Czy KROK 4 zamykamy i przechodzimy do KROKU 5 (engine + registry + TracksSource;
   zero silent defaults + StaticOrderRouter)?

## Checkpoint 5 — po KROKU 5 (engine + registry + StaticOrderRouter)

Data: 2026-08-18.
Status: **CLOSED** (wykonanie) — do potwierdzenia przez Operatora.

Zakres:
- Core (D/17): `ExecutionTrack.provider` (wymagane, walidowane).
- Adaptery (D/18): `LlmAdapter` + `baseUrl` + `mapError` (parity statusów z proxy).
- `_shared/engine/` — NOWA warstwa transportu: `router.ts` (StaticOrderRouter — wariant A),
  `registry.ts` (parseTracks z LLM_TRACKS, resolveCarrierKey), `engine.ts` (Engine: selekcja
  tracków po zdolnościach, required pierwsze, C-0 fallback po modelach i trackach,
  transport wstrzykiwany, NOT_CONFIGURED/NO_MODELS — zero silent defaults), `index.ts`.
- Brama rozszerzona (K5): router/registry czyste; engine = jedyna warstwa z fetch (bez
  zależności zewnętrznych); core ma provider; adaptery mają baseUrl i mapError.

Dowody:
- `deno test --allow-read _shared/import_gate_test.ts _shared/core/core_test.ts
  _shared/adapters/adapters_test.ts _shared/engine/engine_test.ts _shared/prompts/prompts_test.ts
  _shared/backoff_test.ts`: **73 passed | 0 failed**
  (engine 14 + adaptery 9 + core 7 + brama 11 + prompts 25 + backoff 7).
- Regresja (bez zmian zachowania proxy; harness przez `deno run`):
  - openrouter-proxy **OK** (LLM=3, RPC=1);
  - gemini-proxy **OK** (LLM=3, RPC=1).
- `git status`: nowe `_shared/engine/`, zmiany `_shared/core/` i `_shared/adapters/`,
  rozszerzenie bramy i testów — bez commita.

Decyzja do potwierdzenia przez Operatora:
1. Czy KROK 5 zamykamy i przechodzimy do KROKU 6?

## Checkpoint 6 — po KROKU 6 (polityki tracków + utwardzenie engine)

Data: 2026-08-18.
Status: **CLOSED** (wykonanie) — do potwierdzenia przez Operatora.

Zakres:
- Core (additive, J.5): `TrackPolicy` (interfejs) + `PolicyResult`; `DataPolicyDeclaration`
  (region/training/retentionDays) + `ExecutionTrack.dataPolicy?` — minimalna oś Supplier/Route,
  aktywne deklaracje, pusta egzekucja; walidacja kształtu w `validateExecutionTrack`.
- `_shared/engine/policies.ts` — NOWE: `CapabilityPolicy` (formalizacja selekcji D/19),
  `DataPolicy` (pusta egzekucja). Czyste (bez fetch/Deno/jsr/npm).
- `_shared/engine/engine.ts` (utwardzenie, opt-in — parity bez podania): `IExecutionEngine`
  (Engine implementuje); łańcuch polityk `policies?` (domyślnie `[CapabilityPolicy]`,
  NOT_CONFIGURED z `providerDetail`); R3 `forwardUserId?` (domyślnie true = parity);
  `budget?: { maxAttempts, deadlineMs }`; `requestTimeoutMs?` (E4 — AbortController → timeout).
- Brama rozszerzona (K6): policies czyste; core ma TrackPolicy/DataPolicyDeclaration/dataPolicy
  (zero importów); engine ma IExecutionEngine/policies/forwardUserId/budget/requestTimeoutMs/AbortController.

Dowody:
- `deno test --allow-read _shared/import_gate_test.ts _shared/core/core_test.ts
  _shared/adapters/adapters_test.ts _shared/engine/engine_test.ts _shared/prompts/prompts_test.ts
  _shared/backoff_test.ts`: **86 passed | 0 failed**
  (engine 22 + adaptery 9 + core 8 + brama 14 + prompts 25 + backoff 7).
- Regresja (bez zmian zachowania proxy; harness przez `deno run`):
  - openrouter-proxy **OK** (LLM=3, RPC=1);
  - gemini-proxy **OK** (LLM=3, RPC=1).
- `git status`: nowe `_shared/engine/policies.ts`, zmiany `_shared/core/`, `_shared/engine/`,
  bramy i testów — bez commita.

Decyzja do potwierdzenia przez Operatora:
1. Czy KROK 6 zamykamy i przechodzimy do KROKU 7 (llm-gateway + runtime switch + R7)?

## Checkpoint 7 — po KROKU 7 (llm-gateway + runtime switch + naprawa R7)

Data: 2026-08-18.
Status: **CLOSED** (wykonanie) — do potwierdzenia przez Operatora.

Zakres:
- `_shared/host.ts` — NOWE: wspólne moduły hosta (CORS/json/safeErrorMessage/decodeJwtUserId/
  ApiUpstreamError/validateBody) wydzielone z openrouter-proxy 1:1; CORS czytany leniwie
  (import bez --allow-env). Legacy proxy nie refaktorowane (aliasy do KROKU 8).
- `llm-gateway/index.ts` — NOWE (Edge Function, verify_jwt): JWT-userId → rate-limit RPC →
  validateBody → engine.execute → HTTP. Composition root (adaptery gemini/openrouter,
  polityki [CapabilityPolicy, DataPolicy], budżet i timeout z env, opt-in). Tracki z LLM_TRACKS.
  Kontrakt odpowiedzi identyczny z legacy proxy; błędy = kanoniczne kody + status.
- `config.toml`: rejestracja `[functions.llm-gateway]` (verify_jwt = true).
- Klient Flutter (`supabase_api_service.dart`): runtime switch (SUPABASE_LLM_FUNCTION override →
  domyślnie llm-gateway) + fallback legacy openrouter-proxy przy 503 (bez pętli) + setter
  `useLlmFunction()`.
- R7 (`lib/models/report.dart`): defensywna walidacja overall_rating 1–5, spoza zakresu → 3.
- Brama rozszerzona (K7): host eksportuje pełne API; gateway to kompozycja (bez duplikacji
  promptów / parsowania payloadów providera).

Dowody:
- `deno test --allow-read --allow-env` (całość _shared/ + host_test): **95 passed | 0 failed**
  (+9 = host 7 + brama K7 2).
- Harness llm-gateway (`deno run`): **OK** — report C-0 przez engine (EMPTY→INVALID→3. model,
  gemini=3), chat persona (critic, bez innych person, remaining), upstream 429 → RATE_LIMITED
  (429 + retry_after_seconds=3).
- Regresja legacy (bez zmian zachowania proxy): openrouter **OK** (LLM=3, RPC=1),
  gemini **OK** (LLM=3, RPC=1).
- Flutter: `flutter analyze` (lib/services/supabase_api_service.dart, lib/models/report.dart)
  czysty; `flutter test`: **46 PASS**.
- `git status`: nowe `_shared/host.ts`, `host_test.ts`, `llm-gateway/` (index + harness),
  zmiany `config.toml`, `supabase_api_service.dart`, `report.dart`, brama K7 — bez commita.

Decyzja do potwierdzenia przez Operatora:
1. Czy KROK 7 zamykamy i przechodzimy do KROKU 8 (deprecacja legacy proxy — przełączenie na
   llm-gateway, usunięcie starych ścieżek/duplikacji)?

## Checkpoint 8 — po KROKU 8 (deprecacja legacy; llm-gateway jedynym hostem LLM)

Data: 2026-08-18.
Status: **CLOSED** (wykonanie) — do potwierdzenia przez Operatora.

Zakres:
- Usunięte `supabase/functions/gemini-proxy/` i `supabase/functions/openrouter-proxy/`
  (index.ts + harnessy regresyjne). F0 domknięty de facto — transpilowany gemini-proxy/index.ts
  znika z repo (typowany TS: adapter w `_shared/`, host w `llm-gateway`).
- `config.toml`: usunięte sekcje legacy; `[functions.llm-gateway]` jedynym hostem LLM.
- Klient (`supabase_api_service.dart`): usunięty fallback legacy (retry przy 503); zostaje
  runtime switch (`useLlmFunction()` + override SUPABASE_LLM_FUNCTION), domyślnie llm-gateway.
- Usunięty martwy `lib/core/constants/api_endpoints.dart` (nieużywana ścieżka legacy).
- E2E smoke-test przeniesiony: `llm-gateway/e2e_smoke_test.ts` (łańcuch auth → llm-gateway →
  session-proxy → czystość 404), bez zmian asercji/bezpieczeństwa.
- Brama K8: legacy proxy nie istnieją; llm-gateway ma harness + e2e_smoke (na llm-gateway);
  klient bez openrouter-proxy/gemini-proxy, z useLlmFunction. Nieaktualny test bramy K2 usunięty.
- Komentarze bieżącego stanu zaktualizowane (host/prompts/llm-gateway/adaptery/persona/chat_screen).

Dowody:
- `deno test --allow-read --allow-env` (całość _shared/ + host_test): **97 passed | 0 failed**
  (brama K8 3; usunięty 1 nieaktualny test K2 o importach proxy).
- Harness llm-gateway (`deno run`): **OK** (report C-0, chat persona, RATE_LIMITED).
- Flutter: `flutter analyze` (supabase_api_service, chat_screen, persona, report) czysty;
  `flutter test`: **46 PASS**.
- `git status`: usunięte gemini-proxy/openrouter-proxy + api_endpoints.dart; zmiany config.toml,
  supabase_api_service.dart, import_gate_test, komentarze; nowe llm-gateway/e2e_smoke_test.ts
  — bez commita.

Decyzja do potwierdzenia przez Operatora:
1. Czy KROK 8 zamykamy i przechodzimy do KROKU 9 (finalna integracja + Data Safety + submission)?

## Planowane checkpointy (przyszłe)

- CP9 — zewnętrzny: RevenueCat Shipaton 2026 (monitorowanie regulaminu).
- CP10 — finalna integracja + Data Safety + submission.