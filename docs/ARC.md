# ARC — Architectural Record (LLM Foundation)

Dokument prowadzony na bieżąco (rytm: KROK → WRITE → TEST → DOWÓD → DOKUMENTACJA → STOP).
Wpisy dołączane chronologicznie; nie nadpisywane.

## Architektura docelowa v2.0 (zaakceptowana przez Operatora 2026-08-17/18)

Decyzja: **B — kontrolowana migracja fundamentu LLM** (bez budowy od zera, bez pozostawienia bez zmian).

Komponenty docelowe (LLM Foundation):
- **Core** — kontrakty nośnikowo-niezależne: `Part/Content`, `CanonicalError`, `ExecutionTrack`,
  `TaskSpec`, `CapabilityId`, kontrakty odpowiedzi (`ReportContract` jako wzorzec),
  `ArtifactRef`, deklaracja `IArtifactStore`.
- **Engine** — `IExecutionEngine`: transport HTTP + pętla nad modelami (w tym zachowanie C-0),
  retry/backoff (G.2), timeout/AbortSignal (E4).
- **Adapter** — czyste tłumacze (bez fetch): `IGeminiAdapter`, `IOpenRouterAdapter`;
  gemini-proxy staje się adapterem typowanym TS (F0 — nowy kod, nie „odtworzenie").
- **Provider/Model/Supplier** — opisy konfiguracji i zdolności (CapabilityId).
- **Route/Policy/Registry** — `TrackRegistry` (zero cichych defaultów), `TrackRouter` (interfejs,
  deklarowany w core; jedyna impl `StaticOrderRouter`), polityki minimalne.
- **llm-gateway** — nowa Edge Function: wejście klienta, wybór tracka, delegacja do engine.
- **Artifact Storage / Orchestration / streaming / multimodalność** — interfejsy i typy teraz,
  implementacje FUTURE (świadomie, nie ignorowane).

Zasady wykonania: zero silent defaults; execution fallback ≠ configuration default;
dokumentacja jako warunek przejścia etapu; klasyfikacja FACT/PROPOSAL/HYPOTHESIS/DECISION/FUTURE.

## Stan v0 (legacy — punkt startowy migracji)

- Dwie Edge Functions: `gemini-proxy` (transpilowany JS, brak typów) i `openrouter-proxy` (TS).
- „Kontrakt" = wspólne kształty odpowiedzi (`{results…, remaining}` / `{report, remaining}`),
  walidacja `parseReport` (prompts/index.ts, źródło prawdy promptów — D1).
- Wybór providera w buildzie: `String.fromEnvironment('SUPABASE_LLM_FUNCTION', 'openrouter-proxy')`
  (lib/services/supabase_api_service.dart). Brak cross-provider fallbacku.
- Brak silnika/engine; brak routera; brak timeoutów (E4).
- userId: JWT sub → lokalny decode → RPC `p_user_id` (oba proxy); OpenRouter otrzymuje `user`
  w payloadcie, Gemini nie wysyła userId upstream.

## Ewolucja

### KROK 1 — C-0, BS-3, GEMINI_NOT_CONFIGURED (2026-08-18)

Zakres zatwierdzony przez Operatora; lokalizacja dokumentacji ustalona na `benedictum-mobile/docs/`.

1. **C-0 (D1):** naruszenie kontraktu przy `200` (EMPTY_RESPONSE / INVALID_REPORT) przestało kończyć
   całą ścieżkę — `lastError` + `continue` (próba kolejnego modelu z listy), spójnie z 429/400/403.
   Miejsca: gemini-proxy/index.ts (callGemini, callGeminiReport), openrouter-proxy/index.ts
   (callOpenRouterReport, callOpenRouter; extractContent zwraca `string | null`).
   Efekt: przy wyczerpaniu listy propagowany jest OSTATNI błąd kontraktu (jak wcześniej).
2. **BS-3:** `thinkingConfig: { thinkingBudget: 0 }` w obu `generationConfig` gemini-proxy.
   Model pozostaje `gemini-2.5-flash`; myślenie wyłączone (symetria z `reasoning: {enabled:false}`
   w openrouter-proxy). Usuwa ryzyko zjedzenia `maxOutputTokens` przez tokeny thinking.
3. **GEMINI_NOT_CONFIGURED (fail-fast):** brak `GEMINI_API_KEY` → jawny `503` przed RPC
   rate-limit (po autoryzacji JWT). Zero cichych defaultów (J.4).

Dowód: testy regresyjne `fallback_regression_test.ts` (oba proxy) + istniejące 39 testów PASS.
Zob. CHECKPOINTS.md i DECISIONS_LOG.md.

### KROK 2 — `_shared/` extraction + brama importów (2026-08-18)

Zakres zatwierdzony przez Operatora (GO → KROK 2; bez automatycznego przejścia do KROKU 3).

1. **`_shared/prompts/`** — SOURCE OF TRUTH promptów (D1) przeniesiony z `gemini-proxy/prompts/`
   (index.ts + 5 szablonów + prompts_test.ts). Jeden kanon; koniec cross-importu B1
   (openrouter-proxy przestał importować `../gemini-proxy/prompts/`).
2. **`_shared/backoff.ts` + `_shared/backoff_test.ts`** — konsolidacja zdublowanej logiki
   Retry-After (G.2) obu proxy. Rola w architekturze v2.0: narzędzie silnika (engine),
   nie adaptera; wcześniejszy komentarz „izolacja providera… Krok 3" unieważniony (zob.
   DECISIONS_LOG D-2026-08-18/6).
3. **Brama KROKU 2: `_shared/import_gate_test.ts`** — dynamiczne załadowanie przeniesionych
   modułów + sprawdzenie publicznego API + statyczna kontrola, że oba proxy importują
   wyłącznie z `../_shared/` + brak fizycznych starych ścieżek.

Dowód: brama + prompts 25 + backoff 7 = 36 passed; regresja obu proxy po przeniesieniu PASS.
Zob. CHECKPOINTS.md (Checkpoint 2) i DECISIONS_LOG.md.

### KROK 3 — Core types v1.1 (2026-08-18)

Zakres zatwierdzony przez Operatora (GO → KROK 3; bez automatycznego przejścia do KROKU 4).

1. **`_shared/core/index.ts`** — czysty moduł (zero importów zewnętrznych; TYLKO typy + czyste
   funkcje) wg listy D8: `Part/Content`, `CanonicalError`, `ExecutionTrack`, `TaskSpec`,
   `CapabilityId`, `ArtifactRef`, deklaracja `IArtifactStore`, `TrackRouter` (interfejs — wariant A)
   oraz `ReportContract` (kanon kontraktu). Fabryki/walidatory wymuszają jawne parametry
   (zero silent defaults, J.4); unie `Part`/`CapabilityId` rozszerzalne bez przebudowy (J.5/J.6).
2. **Kanon kontraktu bez dryfu:** `ReportContract` przeniesiony do core; `_shared/prompts`
   re-eksportuje typ z core (walidacja `parseReport` pozostaje w prompts do KROKU 4).
   Brama sprawdza, że nie ma dryfu i że core nie importuje niczego.
3. **`_shared/core/core_test.ts`** — testy runtime (fabryki, walidatory, CanonicalError,
   no-drift kontraktu) + użycie typów na poziomie kompilacji (type-check testu weryfikuje
   powierzchnię typów).

Dowód: core 5 + brama 6 + prompts 25 + backoff 7 = 43 passed; regresja obu proxy PASS.
Zob. CHECKPOINTS.md (Checkpoint 3) i DECISIONS_LOG.md.

### KROK 4 — Adaptery LLM: czyste tłumacze (2026-08-18)

Zakres zatwierdzony przez Operatora (GO → KROK 4; bez automatycznego przejścia do KROKU 5).

1. **`_shared/core/index.ts` (rozszerzenia additive, J.5):** `TaskSpec` + `mode?:
   "intake" | "analyze"` i `userId?: string`; `createTaskSpec` waliduje `mode` (TypeError).
   `parseReport` przeniesiony do core — kanon walidacji kontraktu (D/10 domknięty).
   Core nadal czysty: zero importów.
2. **`_shared/prompts/index.ts`:** re-eksport `parseReport` z core (`export { parseReport }
   from "../core/index.ts"`) — API bez zmian dla proxy (wsteczna zgodność do KROKU 5/7).
3. **`_shared/adapters/` — NOWA warstwa (czyste tłumacze):**
   - `types.ts` — `ProviderAuth`, `ProviderRequest` (method/path/query/headers/body),
     `ProviderResult` (chat|report), `ProviderParseResult` (empty|invalid — rozróżnienie
     dla C-0), interfejs `LlmAdapter { providerId, buildRequest, parseResponse }`.
   - `gemini.ts` (`geminiAdapter`) — parity z gemini-proxy: `/v1beta/models/${model}:generateContent`,
     query `{key}`, `system_instruction/contents/generationConfig` z `thinkingConfig:
     {thinkingBudget: 0}` (BS-3), `maxOutputTokens`/`temperature` z TaskSpec.
   - `openrouter.ts` (`openrouterAdapter`) — parity z openrouter-proxy:
     `/api/v1/chat/completions`, `Authorization: Bearer`, `reasoning: {enabled: false}`,
     `user: task.userId` (R3), `max_tokens` z TaskSpec.
   - **Bez transportu:** zero `fetch`, zero `Deno.*`, zero jsr/npm (brama K4). Transport,
     secrets i retry należą do engine (KROK 5).
   - Persona: mode `"intake"` → `"coach"`; `"analyze"` → `task.persona` (TypeError przy braku).
4. **`_shared/adapters/adapters_test.ts`** — 6 testów: parity payloadów 1:1, parsing
   (empty/invalid/ok), wybór persony, TypeError przy braku message/persony.
5. **Brama rozszerzona (K4):** adaptery czyste (bez `fetch(`/`Deno.`/`jsr:`/`npm:`);
   `parseReport` zdefiniowany tylko w core; prompts tylko re-eksportuje; adaptery importują
   `parseReport` wyłącznie z core.

Dowód: adaptery 6 + prompts 25 + core 7 + brama 8 + backoff 7 = 53 passed; regresja obu proxy
PASS (harness przez `deno run` — D-2026-08-18/16). Zob. CHECKPOINTS.md (Checkpoint 4)
i DECISIONS_LOG.md.

### KROK 5 — Engine LLM: transport + registry + StaticOrderRouter (2026-08-18)

Zakres zatwierdzony przez Operatora (GO → KROK 5; bez automatycznego przejścia do KROKU 6).

1. **Core (rozszerzenia additive, D/17):** `ExecutionTrack.provider` (klucz do mapy adapterów
   engine) — wymagane, walidowane w `validateExecutionTrack`; `database` carrier nadal FUTURE.
2. **Adaptery (D/18):** `LlmAdapter` + `baseUrl` (stała providera) i `mapError(status,
   retryAfterSeconds, ctx)` — status → CanonicalError, parity z proxy (gemini: 429 →
   RATE_LIMITED, 400/403 → QUOTA_EXHAUSTED, reszta → UPSTREAM_ERROR; openrouter: 429 →
   RATE_LIMITED, 404 → MODEL_OR_POLICY_BLOCKED, 400/401/402/403 → QUOTA_EXHAUSTED,
   reszta → UPSTREAM_ERROR; model w providerDetail dla openrouter — jak w proxy).
3. **`_shared/engine/` — NOWA warstwa (transport; jedyna warstwa z fetch):**
   - `router.ts` — `StaticOrderRouter` (wariant A): modele w kolejności listy tracka (kopia).
   - `registry.ts` — `parseTracks` (LLM_TRACKS → walidowane tracki; pusta → []),
     `resolveCarrierKey` (sekret nośnika → `apiKey`, jawne). Zero silent defaults.
   - `engine.ts` — `Engine`: selekcja tracków po zdolnościach (task.capabilities ⊆ track),
     required pierwsze; w tracku pętla modeli (router) z C-0 (EMPTY_RESPONSE/INVALID_REPORT →
     next), błędy HTTP → `mapError` adaptera, ostatni błąd wygrywa; transport wstrzykiwany
     (`Transport`, default `fetchTransport` buduje URL z baseUrl + path + query);
     brak tracków/zdolności/sekretu/adaptera → `NOT_CONFIGURED`; brak modeli → `NO_MODELS`.
   - `index.ts` — wspólna powierzchnia importowa.
4. **Brama rozszerzona (K5):** router/registry czyste (bez fetch/Deno/jsr/npm); engine ma
   transport (fetch) bez zależności zewnętrznych; core ma `provider`; adaptery mają
   `baseUrl` i `mapError`.

Dowód: engine 14 + adaptery 9 + core 7 + brama 11 + prompts 25 + backoff 7 = 73 passed;
regresja obu proxy PASS. Zob. CHECKPOINTS.md (Checkpoint 5) i DECISIONS_LOG.md.

### KROK 6 — Polityki tracków + utwardzenie engine (IExecutionEngine, budżet, E4, R3) (2026-08-18)

Zakres zatwierdzony przez Operatora (GO → KROK 6; bez otwierania KROKU 7, bez elementów FUTURE;
taksonomia błędów i interfejs adaptera NIEnaruszone).

1. **Core (rozszerzenia additive, J.5):**
   - `TrackPolicy` (interfejs) + `PolicyResult` — kontrakt kwalifikacji w core (precedens D/11).
   - `DataPolicyDeclaration` (`region`/`training`/`retentionDays`) + `ExecutionTrack.dataPolicy?`
     — minimalna oś Supplier/Route: **aktywne deklaracje, pusta egzekucja** (walidacja kształtu
     w `validateExecutionTrack`; egzekwowanie regionu/treningu = FUTURE). Podstawa Data Safety.
2. **`_shared/engine/policies.ts`** — czyste, wymienialne polityki:
   - `CapabilityPolicy` — formalizacja selekcji po zdolnościach (była wbudowana w engine, D/19);
   - `DataPolicy` — pusta egzekucja (deklaracje aktywne), obecność w łańcuchu = wymienialna oś.
3. **`_shared/engine/engine.ts` (utwardzenie):**
   - `IExecutionEngine` (kontrakt silnika — REPLACEABLE ENGINE); `Engine implements IExecutionEngine`.
   - Łańcuch polityk `policies?: TrackPolicy[]` (domyślnie `[CapabilityPolicy]` — parity z D/19;
     brak kwalifikacji → `NOT_CONFIGURED` z `providerDetail: "<policyId>:<reason>"`).
   - **R3:** `forwardUserId?: boolean` — brama przekazania `task.userId` do upstreamu (domyślnie
     true = obecne zachowanie/parity; false → strip na kopii taska, bez mutacji wejścia).
   - **Budżet:** `budget?: { maxAttempts, deadlineMs }` (opt-in; domyślnie bez limitów = parity).
   - **E4:** `requestTimeoutMs?: number` — AbortController na pojedyncze żądanie (opt-in);
     AbortError → `UPSTREAM_ERROR` z `providerDetail: "<model>:timeout"` (C-0 → następny model).
   - Bez zmian taksonomii: budżet/czas = `UPSTREAM_ERROR` z `providerDetail` (brak nowych kodów).
4. **Brama rozszerzona (K6):** policies czyste (bez fetch/Deno/jsr/npm); core ma `TrackPolicy`/
   `DataPolicyDeclaration`/`dataPolicy` (nadal zero importów); engine ma `IExecutionEngine`,
   łańcuch polityk, `forwardUserId`, `budget`, `requestTimeoutMs` + `AbortController`.

Dowód: engine 22 + adaptery 9 + core 8 + brama 14 + prompts 25 + backoff 7 = **86 passed | 0 failed**
(polityki 5, R3 2, budżet 2, E4 1, interfejs 1, dataPolicy 1, brama K6 3); regresja obu proxy PASS.
Zob. CHECKPOINTS.md (Checkpoint 6) i DECISIONS_LOG.md.

### KROK 7 — llm-gateway (thin host na engine) + runtime switch + naprawa R7 (2026-08-18)

Zakres zatwierdzony przez Operatora (GO → KROK 7; bez otwierania KROKU 8, bez deprecacji legacy).

1. **`_shared/host.ts`** — wspólne moduły hosta (wydzielone z openrouter-proxy 1:1, parity):
   - `corsResponse()` / `json()` (lazy `CORS_ORIGINS` — import bez wymaganego `--allow-env`);
   - `safeErrorMessage()` (redakcja kluczy AIza/sk-/JWT, cięcie >200);
   - `decodeJwtUserId()` (wyciąga `sub` z Bearer JWT; podpis weryfikuje platforma — verify_jwt);
   - `ApiUpstreamError` + `validateBody()` (ChatBody/ReportBody — MISSING_*/INVALID_* 422).
   - Legacy proxy NIE refaktorowane — pozostają aliasami (deprecacja w KROKU 8).
2. **`llm-gateway/index.ts`** — THIN HOST (nowa Edge Function, `verify_jwt = true`):
   - Sekwencja: OPTIONS/405 → JWT-userId (401) → rate-limit RPC `check_rate_limit` (429/503)
     → `validateBody` (422) → `engine.execute` → HTTP.
   - Composition root: `Engine` z adapterami `{ gemini, openrouter }`, łańcuchem polityk
     `[CapabilityPolicy, DataPolicy]`, budżetem i timeoutem **z env** (`LLM_MAX_ATTEMPTS`,
     `LLM_DEADLINE_MS`, `LLM_REQUEST_TIMEOUT_MS` — opt-in, domyślnie parity z proxy).
   - Tracki z `LLM_TRACKS` (JSON, `validateExecutionTrack`, nośnik secret-json `{"apiKey": …}`);
     niepoprawny JSON → `NOT_CONFIGURED` (503), szczegóły w logach.
   - Kontrakt odpowiedzi **identyczny** z legacy proxy: chat `{ critic, optimist, coach, remaining }`,
     report `{ report: {…}, remaining }`; błędy → kanoniczne kody CanonicalError z `status`.
   - mapowanie: `RATE_LIMITED` → 429 + `retry_after_seconds`; EMPTY_RESPONSE/INVALID_REPORT → 422;
     reszta → status z CanonicalError (503); `providerDetail` tylko w logach (sanitarna odpowiedź).
3. **Klient Flutter — runtime switch (`supabase_api_service.dart`):**
   - `_llmFunctionName` czytane w **runtime**: override kompilacji `SUPABASE_LLM_FUNCTION` (dev/legacy)
     lub domyślnie `llm-gateway`; setter `useLlmFunction()` (przełączenie bez przebudowy).
   - Awaryjny fallback: 503 z bieżącej funkcji → retry na legacy `openrouter-proxy`
     (np. gateway nie skonfigurowany); brak nieskończonej pętli (fallback tylko gdy bieżąca ≠ legacy).
4. **R7 (naprawa, `lib/models/report.dart`):** defensywna walidacja `overall_rating` — kontrakt 1–5;
   spoza zakresu / nie-liczba → neutralne **3** (zamiast łamanego „0/5"). Backend egzekwuje
   (`parseReport` w core), klient broni się przed untrusted input.
5. **Brama rozszerzona (K7):** host eksportuje `validateBody`/`corsResponse`/`json`/`decodeJwtUserId`/
   `safeErrorMessage` + `ApiUpstreamError`; gateway to kompozycja (importuje `_shared/host` + engine,
   wywołuje `engine.execute`), NIE duplikuje promptów ani parsowania payloadów providera.

Dowód: deno unit **95 passed | 0 failed** (+9: host 7 + brama K7 2); harness llm-gateway **OK**
(report C-0 przez engine: EMPTY→INVALID→3. model; chat persona; upstream 429 → RATE_LIMITED);
regresja obu legacy proxy PASS; Flutter analyze czysty; Flutter **46 testów PASS**.
Zob. CHECKPOINTS.md (Checkpoint 7) i DECISIONS_LOG.md.

### KROK 8 — deprecacja legacy proxy; llm-gateway jedynym hostem LLM (2026-08-18)

Zakres zatwierdzony przez Operatora (GO → KROK 8; płynne przejście po zamknięciu KROKU 7).

1. **Usunięcie legacy proxy (duplikacje/krótsza powierzchnia):**
   - `supabase/functions/gemini-proxy/` i `supabase/functions/openrouter-proxy/` usunięte
     (index.ts + harnessy regresyjne `fallback_regression_test.ts`). F0 domknięty de facto:
     transpilowany `gemini-proxy/index.ts` znika z repo, typowany TS żyje w `_shared/` (adapter)
     i `llm-gateway` (host).
   - `config.toml`: usunięte sekcje `[functions.gemini-proxy]` i `[functions.openrouter-proxy]`;
     `[functions.llm-gateway]` to jedyny host LLM (`verify_jwt = true`).
2. **Klient Flutter (`supabase_api_service.dart`):** usunięty awaryjny fallback legacy
   (`_legacyFallbackFunctionName`, retry przy 503). Zostaje **runtime switch**
   (`useLlmFunction()` + override `SUPABASE_LLM_FUNCTION`), domyślnie `llm-gateway`.
3. **Martwy kod:** usunięty `lib/core/constants/api_endpoints.dart` (nieużywany
   `geminiProxyPath = '/functions/v1/gemini-proxy'` — ścieżka legacy).
4. **E2E smoke-test przeniesiony** (trwały artefakt Fali 2B): `openrouter-proxy/e2e_smoke_test.ts`
   → `llm-gateway/e2e_smoke_test.ts` (łańcuch: auth → **llm-gateway** report → session-proxy
   POST/GET/DELETE → czystość 404). Bez zmian asercji/bezpieczeństwa.
5. **Brama K8:** legacy proxy nie istnieją; `llm-gateway` ma harness regresyjny + e2e_smoke
   wskazujący na llm-gateway; klient bez `openrouter-proxy`/`gemini-proxy` (tylko `llm-gateway`
   + `useLlmFunction`). Test bramy K2 o importach proxy usunięty (nieaktualny).
6. **Komentarze** (stan bieżący): host.ts / prompts / llm-gateway / adaptery / persona / chat_screen
   wskazują llm-gateway i fakt usunięcia legacy (odniesienia historyczne „parity z legacy" zachowane).

Dowód: deno unit **97 passed | 0 failed** (brama K8 3, usunięty nieaktualny test K2);
harness llm-gateway **OK** (report C-0, chat persona, RATE_LIMITED); Flutter analyze czysty;
Flutter **46 testów PASS**. Zob. CHECKPOINTS.md (Checkpoint 8) i DECISIONS_LOG.md.
### T1 — STT semantyka + fallback cloud; A3.6 voice end-to-end (2026-08-20)

Zakres zatwierdzony przez Operatora (GO → T1 SEMANTYKA → CONTROLLED WRITE → opcja 1).

1. **Korekta semantyczna pluginu `speech_to_text` 7.4.0** (pub-cache, **POZA repo**):
   `final_result=true` + niepuste `userSaid` → `ResultType.finalResult` (nie `intermediate`);
   pusty `onResults` → `EMPTY_PATH` (nie nadpisuje finala).
   `SpeechToTextPlugin.kt:477-482` (REPRODUCIBILITY RISK — B11/U-T1-02).
2. **Fallback cloud w `VoiceService`** (hybryda R1-C): `minOnDeviceWordCount = 4`
   (`voice_service.dart:155`) — on-device < 4 słów uznawane za niekompletne → fallback cloud.
   Próg 4 (nie 3): przebieg 16:33 pokazał, że on-device potrafi rozpoznać szum tła jako
   3 słowa (`/tmp/opencode/t1cf2_console.txt:84`).
3. **A3.6 end-to-end PASS** (S23 Ultra, 16:37): keywords 4/4, `lastSttMode=onDevice`,
   TTS full cycle; commit `6a33de0` (voice_service.dart, chat_screen.dart,
   e2e_voice_real_test.dart).
4. **Instrumentacja T1DART/T1KOTLIN** (debugPrint) — ślady `[T1DART-C*]`/`[T1KOTLIN]`.

Dowód: logcat `EMIT resultType=2` + `EMPTY_PATH` (`/tmp/opencode/t1cf3_logcat.txt:12663,12675`);
A3.6 PASS (`/tmp/opencode/t1cf3_console.txt:202`); analyze 0 issues; unit 7/7; build ✓.
Szczegóły: CHECKPOINTS.md (Checkpoint 9), DECISIONS_LOG.md (T1), docs/T1_CLOSURE.md.
