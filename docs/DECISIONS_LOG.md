# DECISIONS_LOG — rejestr decyzji (z uzasadnieniem WHY)

Wpisy dołączane chronologicznie. Format: identyfikator — decyzja — WHY — dowód.

## T1 (2026-08-20) — STT semantyka + fallback cloud + A3.6

### D-2026-08-20/33 — Korekta semantyczna pluginu `speech_to_text`: `final_result`→`finalResult`
Decyzja: w `SpeechToTextPlugin.kt` (pub-cache 7.4.0, POZA repo) mapowanie `final_result=true`
+ niepuste `userSaid` → `ResultType.finalResult` zamiast błędnego `ResultType.intermediate`;
pusty `onResults` → `EMPTY_PATH` (nie nadpisuje finala).
WHY: on-device (Soda) zgłaszał finalne rozpoznanie jako `isFinal=false` — Flutter bez korekty
traktował transkrypcję jako cząstkową i odrzucał ją w progu słów (A3.6 nie przechodził).
Dowód: `SpeechToTextPlugin.kt:477-482`; logcat `EMIT resultType=2` + `EMPTY_PATH`
(`/tmp/opencode/t1cf3_logcat.txt:12663,12675`); powtórka 3× (`resultType=2`, `EMPTY_PATH`).

### D-2026-08-20/34 — Fallback cloud przy wyniku on-device < 4 słów (opcja 1)
Decyzja: `minOnDeviceWordCount = 4` w `voice_service.dart:155`; wyniki on-device poniżej
progu uznawane za niekompletne → `[T1DART-C3b]` → fallback cloud (R1-C).
WHY: on-device potrafi obciąć frazę do ~3 słów i zwrócić je jako finalResult (fakt z przebiegów
10:37/13:06) oraz rozpoznać sam szum tła (przebieg 16:33 `"tak słuchaj ja"`, words=3 przy progu
3 — test FAIL). Próg 3 okazał się za niski (2. przebieg), podniesiony na 4 → PASS.
Dowód: `voice_service.dart:155,170,174-175`; `/tmp/opencode/t1cf2_console.txt:84`;
`/tmp/opencode/t1cf3_console.txt:202` (A3.6 PASS, keywords 4/4).

### D-2026-08-20/35 — Commit T1 zgodnie z workflow (backupy zachowane)
Decyzja: commit `6a33de0` (voice_service.dart, chat_screen.dart, e2e_voice_real_test.dart);
korekta pluginu NIE jest częścią commita (pub-cache) — świadomie.
WHY: decyzja Operatora („commit zgodnie z workflow, zachowując backupy"); plugin poza repo —
do późniejszej decyzji (U-T1-02/B11).
Dowód: `git log 6a33de0`; backupy `/tmp/opencode/t1*_backup/`.

### D-2026-08-20/36 — Dowód gałęzi fallbacku cloud → OSOBNY KROK (nie otwarto)
Decyzja: fallback cloud (`[T1DART-C3b]`→`[C4]`→`SttMode.cloud`) NIE jest testowany w T1.
WHY: w A3.6 PASS on-device dało 8 słów — gałąź fallbacku nie została wykonana; wymaga
osobnego KROKU dowodowego za decyzją Operatora (U-T1-01).
Dowód: brak śladu `SttMode.cloud` w `/tmp/opencode/t1cf3_console.txt` (PASS on-device).

## KROK 8 (2026-08-18)

### D-2026-08-18/29 — Deprecacja legacy proxy: usunięcie gemini-proxy i openrouter-proxy
Decyzja: `supabase/functions/gemini-proxy/` i `supabase/functions/openrouter-proxy/` usunięte
(kod + harnessy regresyjne); sekcje `[functions.gemini-proxy]` i `[functions.openrouter-proxy]`
usunięte z `config.toml`; `llm-gateway` jedynym hostem LLM. F0 domknięty de facto — transpilowany
`gemini-proxy/index.ts` znika z repo (typowany TS: adapter w `_shared/`, host w `llm-gateway`).
WHY: plan KROKU 8 („deprecacja legacy — przełączenie na llm-gateway, usunięcie starych
ścieżek/duplikacji"); koniec podwójnej utrzymywania (hosty LLM: 1 zamiast 3); F0 (transpilat)
przestaje istnieć w repo; legacy proxy nie mają już konsumentów (klient → llm-gateway).
Dowód: brama K8 (proxy nie istnieją) — CHECKPOINTS.md (Checkpoint 8).

### D-2026-08-18/30 — Klient: usunięcie awaryjnego fallbacku legacy (runtime switch zostaje)
Decyzja: `supabase_api_service.dart` bez `_legacyFallbackFunctionName` i retry przy 503; zostaje
runtime switch (`useLlmFunction()` + override `SUPABASE_LLM_FUNCTION`), domyślnie `llm-gateway`.
WHY: D/27 fallback wskazywał na openrouter-proxy — legacy usunięte w KROKU 8 (D/29); fallback
był „awaryjny" tylko na czas przejścia; jeden host = prostszy model awarii (awaria gateway to
awaria LLM — jawna, nie cicha degradacja na ścieżkę, której nie ma).
Dowód: brama K8 (klient bez openrouter-proxy/gemini-proxy, z useLlmFunction); flutter analyze.

### D-2026-08-18/31 — E2E smoke-test przeniesiony z openrouter-proxy na llm-gateway
Decyzja: `openrouter-proxy/e2e_smoke_test.ts` → `llm-gateway/e2e_smoke_test.ts` (łańcuch:
auth → llm-gateway report → session-proxy lifecycle → czystość 404). Bez zmian asercji.
WHY: trwały artefakt Fali 2B (7/7 PASS 2026-08-17) ma wartość tylko przy żywym hoście LLM —
po deprecacji hostem jest llm-gateway; test zachowuje pokrycie pełnego łańcucha produkcyjnego.
Dowód: brama K8 (e2e wskazuje ${FN_BASE}/llm-gateway, brak /openrouter-proxy).

### D-2026-08-18/32 — Usunięcie martwego kodu: `lib/core/constants/api_endpoints.dart`
Decyzja: plik usunięty (nieużywany `geminiProxyPath = '/functions/v1/gemini-proxy'`, `baseUrl`
placeholder bez konsumentów). WHy: „usunięcie starych ścieżek/duplikacji" (plan KROKU 8);
martwa stała o nieistniejącej funkcji wprowadzałaby w błąd; kod bez konsumentów = dług.
Dowód: rg (brak importów/odwołań poza definicją); flutter analyze czysty.

## KROK 7 (2026-08-18)

### D-2026-08-18/25 — Wspólne moduły hosta w `_shared/host.ts` (wydzielone z openrouter-proxy 1:1)
Decyzja: `_shared/host.ts` zawiera `corsResponse()`, `json()`, `safeErrorMessage()`,
`decodeJwtUserId()`, `ApiUpstreamError`, `validateBody()` (ChatBody/ReportBody). CORS_ORIGINS
czytane leniwie (w `corsResponse()`), by sam import hosta nie wymagał `--allow-env` (brama importowa).
Legacy proxy NIE refaktorowane w KROKU 7 (pozostają aliasami; deprecacja w KROKU 8).
WHY: plan KROKU 2 przewidywał „JWT/CORS/validateBody → _shared/" — odłożone do KROKU 7 (moja
rekomendacja w pre-decision); gateway musi mieć te same mechanizmy co proxy bez duplikacji
(thin host = kompozycja, nie duplikacja); parity 1:1 z istniejącym kontraktem.
Dowód: host_test (7 testów: validateBody/JSON, decodeJwtUserId, safeErrorMessage, cors/json) + brama K7.

### D-2026-08-18/26 — llm-gateway: thin host na engine (kompozycja, nie duplikacja)
Decyzja: nowa Edge Function `llm-gateway` (`verify_jwt = true`): JWT-userId → rate-limit RPC →
validateBody → `engine.execute` → HTTP. Composition root: `Engine` z adapterami gemini/openrouter,
łańcuchem `[CapabilityPolicy, DataPolicy]`, budżetem `LLM_MAX_ATTEMPTS`/`LLM_DEADLINE_MS` i timeoutem
`LLM_REQUEST_TIMEOUT_MS` z env (opt-in). Tracki z `LLM_TRACKS` (JSON; niepoprawny → NOT_CONFIGURED).
Kontrakt odpowiedzi identyczny z legacy proxy; błędy = kanoniczne kody + status; `providerDetail`
tylko w logach. Legacy proxy bez zmian (aliasy).
WHY: plan §12 F4 (llm-gateway); engine (KROK 5/6) ma wykonanie + polityki + budżet, host ma
HTTP/auth — rozdzielenie warstw; 1 wspólna brama zamiast 2 proxy z duplikacją walidacji/JWT/CORS.
Dowód: harness llm-gateway OK (report C-0 przez engine, chat persona, 429→RATE_LIMITED) + brama K7.

### D-2026-08-18/27 — Klient: runtime switch funkcji LLM + awaryjny fallback legacy
Decyzja: `supabase_api_service.dart` czyta nazwę funkcji w **runtime** — priorytet: override
kompilacji `SUPABASE_LLM_FUNCTION` (dev/legacy) → domyślnie `llm-gateway`; setter `useLlmFunction()`.
Przy 503 z bieżącej funkcji (np. gateway NOT_CONFIGURED) → retry na legacy `openrouter-proxy`
(tylko gdy bieżąca ≠ legacy — brak pętli).
WHY: plan KROKU 7 — „SUPABASE_LLM_FUNCTION → runtime (awaryjny fallback legacy); domyślny
przełącznik na llm-gateway"; przełączenie bez przebudowy aplikacji; awaria nowej bramy nie
wyłącza aplikacji (fallback legacy).
Dowód: flutter analyze czysty; Flutter 46 testów PASS (brak testu jednostkowego services —
domyślny stan projektu, pozostałe pokrycie przez mock + widget).

### D-2026-08-18/28 — R7: defensywna walidacja `overall_rating` 1–5 w `report.dart`
Decyzja: `Report.fromJson` przyjmuje overall_rating tylko z zakresu 1–5 (int); spoza zakresu /
nie-liczba → neutralne **3** (zamiast dotychczasowego 0, które łamało „X/5" w UI).
WHY: KROK 0 (R7): „backend = enforcement, klient = defensive validation"; untrusted input z LLM
(kontrakt §22); 0 spoza kontraktu prowadziło do „0/5" — wadliwy stan UI.
Dowód: brak osobnego testu modelu (stan projektu — mock 4/5 + widget); zmiana w report.dart
analizowana przez `flutter analyze` (czysty).

## KROK 6 (2026-08-18)

### D-2026-08-18/20 — Polityki tracków: `TrackPolicy` + `CapabilityPolicy` (formalizacja selekcji)
Decyzja: interfejs `TrackPolicy { id, qualify(track, task) → { ok, reason? } }` w core;
engine wykonuje łańcuch polityk `policies?: TrackPolicy[]` (domyślnie `[CapabilityPolicy]` —
parity z D/19). Brak kwalifikacji → `NOT_CONFIGURED` z `providerDetail: "<policyId>:<reason>"`.
WHY: selekcja po zdolnościach przestaje być kodem wbudowanym w engine (D/19) i staje się
wymienialnym mechanizmem (plan KROKU 6: „CapabilityPolicy (requires⊆provides)"); dodanie/usunięcie
polityki bez zmian w engine/core.
Dowód: engine_test (CapabilityPolicy reason, własna polityka BlockAll) + brama K6 — CHECKPOINTS.md.

### D-2026-08-18/21 — Minimalna oś Supplier/Route: `DataPolicyDeclaration` + `dataPolicy` (pusta egzekucja)
Decyzja: `DataPolicyDeclaration { region?, training?, retentionDays? }` + opcjonalne
`ExecutionTrack.dataPolicy` (walidowane w `validateExecutionTrack`); `DataPolicy` w `policies.ts`
zwraca `ok` (egzekucja pusta). Pełny podział Provider/Model/Supplier/Route = FUTURE.
WHY: plan KROKU 6 — „pola na route: region/trening/ZDR — aktywne deklaracje, pusta egzekucja";
podstawa Data Safety (region jurysdykcji, zgoda na trening, retencja); additive (J.5).
Dowód: core_test (dataPolicy valid/invalid) + engine_test (track z deklaracją wykonuje się OK).

### D-2026-08-18/22 — R3: `forwardUserId` — brama przekazania `task.userId` do upstreamu
Decyzja: `EngineDeps.forwardUserId?: boolean` (domyślnie true = obecne zachowanie, parity);
false → strip `userId` na kopii taska przed `buildRequest` (bez mutacji wejścia).
WHY: KROK 0 ustalił „userId: nie wycinamy; dokumentujemy przepływ" — KROK 6 dodaje **mechanizm**
decyzji (composition root), polityka aktywowana jawnie, nie cicho.
Dowód: engine_test (default → body.user="u-1"; forwardUserId=false → body.user=undefined,
task.userId bez zmian).

### D-2026-08-18/23 — Utwardzenie engine: `IExecutionEngine` + budżet + timeout (E4), opt-in
Decyzja: `IExecutionEngine` (kontrakt — REPLACEABLE ENGINE), `budget?: { maxAttempts, deadlineMs }`
(limit prób / twardy czas całego execute), `requestTimeoutMs?: number` (AbortController na żądanie).
Wszystko opt-in — bez podania domyślne zachowanie identyczne jak w KROKU 5 (parity z proxy).
E4: AbortError → `UPSTREAM_ERROR` `providerDetail: "<model>:timeout"` → C-0.
WHY: plan §7 klasyfikuje „engine + budżet + timeout + fail-fast" jako MUST HAVE drogi; KROK 5
zamknięty bez nich (raport pre-decision); opt-in chroni parity; czas/budżet bez nowych kodów
taksonomii (D/24).
Dowód: engine_test (maxAttempts, deadlineMs, requestTimeoutMs) + brama K6.

### D-2026-08-18/24 — Taksonomia błędów NIEnaruszona w KROKU 6
Decyzja: bez zmian `CanonicalErrorCode` (8 kodów, parity D/18); budżet/czas → `UPSTREAM_ERROR`
z `providerDetail` ("budget:maxAttempts" / "budget:deadline" / "<model>:timeout").
WHY: TARGET proponuje inną ósemkę (AUTH_OR_QUOTA, CONTRACT_VIOLATION…) — odrzucone w pre-decision;
obecna zmapowana 1:1 z proxy; brak korzyści teraz.
Dowód: engine_test + brama K6 (brak nowych kodów).

## KROK 5 (2026-08-18)

### D-2026-08-18/17 — `ExecutionTrack.provider` (additive, wymagane)
Decyzja: `ExecutionTrack` + wymagane `provider: string`; `validateExecutionTrack` odrzuca
puste (TypeError). Engine mapuje track → adapter po `provider`.
WHY: bez jawnego providera routing track → adapter wymagałby cichej konwencji (np. prefiks id);
J.4 — jawność, zero silent defaults; rozszerzenie additive (J.5), bez przebudowy core.
Dowód: core_test (provider ""/" " → TypeError) + brama K5 — CHECKPOINTS.md.

### D-2026-08-18/18 — `LlmAdapter` + `baseUrl` i `mapError` (parity z proxy)
Decyzja: adapter posiada `baseUrl` (stała providera: generativelanguage.googleapis.com /
openrouter.ai) oraz `mapError(status, retryAfterSeconds, ctx) → CanonicalError` — dokładnie
mapowanie statusów z obecnych proxy. openrouter: 429 → RATE_LIMITED; 404 → MODEL_OR_POLICY_BLOCKED;
400/401/402/403 → QUOTA_EXHAUSTED (banda CREDENTIALS_OR_QUOTA proxy zblokowana do najbliższego
kodu kanonicznego); reszta → UPSTREAM_ERROR (model w providerDetail). gemini: 429 → RATE_LIMITED;
400/403 → QUOTA_EXHAUSTED; reszta → UPSTREAM_ERROR (bez modelu — jak proxy).
WHY: core deklaruje, że mapowanie błędów providerów należy do adapterów (KROK 4); parity
zachowania z proxy; `baseUrl` — URL providera to domena adaptera (engine buduje pełny URL).
Dowód: adapters_test (baseUrl + mapError 9 testów) + brama K5 — CHECKPOINTS.md.

### D-2026-08-18/19 — Engine: selekcja po zdolnościach, C-0, zero silent defaults
Decyzja: `Engine.execute(task, tracks, env)`: tracki o zdolnościach pokrywających
`task.capabilities`, `required` pierwsze (kolejność stabilna); w tracku pętla modeli (router)
z C-0 (EMPTY_RESPONSE/INVALID_REPORT → kolejny model; błędy HTTP → mapError adaptera; ostatni
błąd wygrywa); brak tracków / brak dopasowania zdolności / brak sekretu nośnika / brak adaptera
→ `NOT_CONFIGURED` (fail-fast dla sekretu i adaptera — parity z proxy); brak modeli → `NO_MODELS`;
Retry-After tylko nośnik w błędzie (brak sleepu — parity z proxy).
WHY: engine = jedyna warstwa z transportem (adaptery czyste — J.3); C-0 spójne z proxy (D1);
zero silent defaults (J.4) — brak konfiguracji jest jawnym błędem, nie cichym domyślnym modelem;
`required` dziś tylko do kolejności — polityka short-circuit na required to FUTURE.
Dowód: engine_test 14/14 (C-0 3-modele, baseUrl/path parity, RATE_LIMITED/QUOTA/MODEL_OR_POLICY,
NOT_CONFIGURED ×4, required-first) — CHECKPOINTS.md.

## KROK 4 (2026-08-18)

### D-2026-08-18/13 — `TaskSpec` + `mode` i `userId` (additive, J.5)
Decyzja: `TaskSpec` zyskuje opcjonalne `mode?: "intake" | "analyze"` i `userId?: string`;
`createTaskSpec` waliduje `mode` (TypeError dla wartości spoza unii). `mode` bez podania =
`undefined` (nie domyślny "analyze" — zero silent defaults).
WHY: (a) adaptery potrzebują `mode` dla wyboru persony (intake → "coach") i budowy promptu;
(b) R3 — `userId` to nośnik kontekstu żądania do OpenRouter (`user`), nie polityka teraz;
(c) rozszerzenie additive (J.5) — brak przebudowy istniejącego core.
Dowód: core_test 7/7 (w tym testy mode/userId) — CHECKPOINTS.md.

### D-2026-08-18/14 — `parseReport` przeniesiony do core (kanon walidacji kontraktu)
Decyzja: definicja `parseReport` przeniesiona z `_shared/prompts` do `_shared/core`; prompts
re-eksportuje wartość (`export { parseReport } from "../core/index.ts"`), zachowując API dla
proxy. Brama (K4) sprawdza: definicja tylko w core, prompts tylko re-eksportuje.
WHY: D/10 zapowiadał przeniesienie walidacji do warstwy kontraktów w KROKU 4; walidacja
odpowiedzi = domena kontraktu (core), a nie domena promptów; jeden kanon (definicja + walidacja)
eliminuje dryf, który D/10 odłożył tymczasowo.
Dowód: brama K4 + core_test 7/7 (parseReport bezpośrednio z core) — CHECKPOINTS.md.

### D-2026-08-18/15 — Warstwa adapterów: czyste tłumacze (bez transportu) w `_shared/adapters/`
Decyzja: `types.ts` (ProviderAuth, ProviderRequest, ProviderResult, ProviderParseResult,
`LlmAdapter`), `gemini.ts` (`geminiAdapter`), `openrouter.ts` (`openrouterAdapter`) — adapter
buduje `ProviderRequest` (tłumaczenie) i parsuje odpowiedź; NIE wykonuje `fetch` (transport,
secrets, retry w engine — KROK 5). Parity 1:1 z obecnymi proxy. Persona: intake → "coach",
analyze → `task.persona` (TypeError przy braku). `ProviderParseResult` rozróżnia
`empty` vs `invalid` (C-0: EMPTY_RESPONSE vs INVALID_REPORT).
WHY: (a) J.3 — czysty tłumacz bez I/O, testowalny bez sieci; (b) F0 domknięty — gemini
jako nowy typowany TS, a nie odtworzenie transpilowanego proxy; (c) engine (KROK 5) ma
jednolity punkt transportu i decyzji fallbacku.
Dowód: adapters_test 6/6 (parity payloadów i parsowania) + brama K4 (czystość: bez
`fetch(`/`Deno.`/`jsr:`/`npm:`) — CHECKPOINTS.md.

### D-2026-08-18/16 — Harness regresyjny to skrypt: `deno run`, nie `deno test`
Decyzja (operacyjna): `fallback_regression_test.ts` obu proxy uruchamiamy przez `deno run`
(top-level + `Deno.exit`), nie `deno test` — runner nie kończy procesu po top-level `Deno.exit(0)`.
WHY: plik jest harnessem (serwer + stub fetch + asercje w skrypcie), nie zbiorem `Deno.test`;
`deno run` kończy się czysto po `Deno.exit` (weryfikacja 2026-08-18). Komendy w
CHECKPOINTS.md (Checkpoint 1) skorygowane.
Dowód: oba proxy PASS przez `deno run` z natychmiastowym wyjściem 0.

## KROK 3 (2026-08-18)

### D-2026-08-18/9 — Core types v1.1 w `_shared/core/index.ts` (czysty moduł)
Decyzja: utworzenie czystego modułu core (typy + czyste funkcje, zero importów zewnętrznych)
z dokładnie listy D8: Part/Content, CanonicalError, ExecutionTrack, TaskSpec, CapabilityId,
ArtifactRef, deklaracja IArtifactStore, TrackRouter (interfejs) oraz ReportContract.
WHY: (a) core musi być wolny od transportu/providerów (adaptery to czyste tłumacze — J.3);
(b) zero silent defaults (J.4) — fabryki walidują jawne parametry, `validateExecutionTrack`
odrzuca niekompletne tracki; (c) unie rozszerzalne — FUTURE (streaming/orchestration/multimodalne
implementacje) nie wymaga przebudowy core (J.5/J.6).
Dowód: core_test 5/5 (type-check testu = weryfikacja powierzchni typów) — CHECKPOINTS.md.

### D-2026-08-18/10 — Kanon kontraktu: `ReportContract` w core; prompts re-eksportuje
Decyzja: definicja `ReportContract` przeniesiona z `_shared/prompts` do core; prompts
re-eksportuje typ (`export type { ReportContract } from "../core/index.ts"`) i zachowuje
`parseReport` (walidację) do KROKU 4.
WHY: pojedynczy kanon kontraktu zapobiega dryfowi między „kontraktem" a „walidacją";
brama (K3) sprawdza brak dryfu; przeniesienie walidacji do warstwy kontraktów adapterów
to zadanie KROKU 4 (bez skoku zależności w KROKU 3).
Dowód: test no-drift (klucze kontraktu = klucze wyniku parseReport); 43 passed łącznie.

### D-2026-08-18/11 — `TrackRouter` zadeklarowany w core (wariant A); impl w KROKU 5
Decyzja: interfejs `TrackRouter { select(track, task): string[] }` w core jako lekki kontrakt;
`StaticOrderRouter` (czyta `models` w kolejności) powstanie w KROKU 5. Bez osobnej warstwy routera.
WHY: wariant A zatwierdzony przez Operatora — gniazdo kontraktu bez budowania infrastruktury;
FUTURE: strategie health/cost/canary jako nowe implementacje interfejsu, bez zmian w core.
Dowód: typ w core; brama K3 (czystość core).

### D-2026-08-18/12 — Nośnik tracka: `CarrierRef` = secret-json teraz, database FUTURE
Decyzja: `CarrierRef` to unia z obsługiwanym dziś `{ kind: "secret-json" }` i zadeklarowanym
FUTURE `{ kind: "database", table, key }`; `validateExecutionTrack` odrzuca nośnik `database`
(na dziś).
WHY: D6 — kontrakt tracków nośnikowo-niezależny teraz, tabela FUTURE; deklaracja typu zapobiega
przebudowie przy dodaniu tabeli.
Dowód: test validateExecutionTrack (database → TypeError).

## KROK 2 (2026-08-18)

### D-2026-08-18/6 — `_shared/` extraction: prompts + backoff; unieważnienie „izolacji providera"
Decyzja: SOURCE OF TRUTH promptów (D1) przeniesiony do `_shared/prompts/`; backoff (G.2)
skonsolidowany do `_shared/backoff.ts` (jeden kanon zamiast zdublowanych kopii obu proxy);
oba proxy importują z `../_shared/`.
WHY: (a) usuwa B1 (openrouter importował z `gemini-proxy/prompts/` — kod współdzielony żył
w funkcji, do której nie należał); (b) w architekturze v2.0 retry/backoff to narzędzie silnika,
więc nie może mieszkać per-provider — tymczasowy komentarz „nie współdzielony… zgodnie
z dyrektywą Krok 3" jest unieważniony (stary plan przewidywał granicę adaptera inaczej);
(c) `_shared/` to natywny mechanizm Supabase dla kodu współdzielonego między funkcjami.
Dowód: brama importów + 36 passed + regresja obu proxy PASS (CHECKPOINTS.md, Checkpoint 2).

### D-2026-08-18/7 — Brama KROKU 2 = `_shared/import_gate_test.ts` (4 testy)
Decyzja: brama sprawdza (1) API przeniesionych modułów, (2) statycznie, że oba proxy importują
wyłącznie `../_shared/prompts/index.ts` i `../_shared/backoff.ts` (bez `./prompts/`, `./backoff.ts`,
`../gemini-proxy/prompts/`), (3) fizyczny brak starych ścieżek.
WHY: gate ma być dowodem na to, że ekstrakcja nie zostawiła niedziałających importów i że B1
nie powróci przy przyszłych edycjach; testy statyczne (czytanie źródła) są tanie i deterministyczne.
Dowód: brama zielona (4/4) — CHECKPOINTS.md.

### D-2026-08-18/8 — Konsolidacja testów backoff (7+7 → 7, jeden kanon)
Decyzja: usunięto `openrouter-proxy/backoff_test.ts` i `gemini-proxy/backoff_test.ts`;
kanonem jest `_shared/backoff_test.ts` (7 przypadków — oba zestawy były identyczne merytorycznie).
WHY: brak utraty pokrycia (identyczna logika i przypadki); bilans testów ujednolicony;
pojedynczy test zapobiega rozjeżdżaniu się kopii.
Dowód: 7/7 backoff PASS w `_shared/`.

## KROK 1 (2026-08-18)

### D-2026-08-18/1 — C-0: błąd kontraktu 200 → `lastError` + `continue`
Decyzja: naruszenie kontraktu przy statusie 200 (EMPTY_RESPONSE, INVALID_REPORT) nie kończy ścieżki;
pętla próbuje kolejny model z listy; po wyczerpaniu listy rzucany jest ostatni błąd.
WHY: (a) zachowanie spójne z istniejącą obsługą 429/400/403 (G.2); (b) kontrakt odpowiedzi nie może
deterministycznie kończyć wykonania, gdy dostępna jest lista modeli; (c) zachowanie końcowe przy
jednym modelu/pełnej awarii bez zmian (ten sam status/kod błędu).
Dowód: `fallback_regression_test.ts` obu proxy — 3 modele (empty → invalid → valid) → wynik z 3. modelu.

### D-2026-08-18/2 — BS-3: `thinkingConfig: { thinkingBudget: 0 }` w gemini-proxy
Decyzja: wyłączenie myślenia w obu `generationConfig`; model `gemini-2.5-flash` bez zmian.
WHY: dla serii 2.5 domyślny tryb myślenia to dynamic (budget −1); tokeny thinking są liczone do
`maxOutputTokens`; znany błąd #782 (MAX_TOKENS → pusta odpowiedź); mały budżet (300/800) mógł być
„zjadany" przez thinking. Symetria z `reasoning: {enabled: false}` w openrouter (e56ce6e).
Dowód: diff payloadów; testy PASS.

### D-2026-08-18/3 — GEMINI_NOT_CONFIGURED (fail-fast) w KROKU 1
Decyzja: brak `GEMINI_API_KEY` → `503 { error: "GEMINI_NOT_CONFIGURED" }` po autoryzacji JWT,
przed RPC rate-limit.
WHY: zero cichych defaultów (J.4); dotychczasowy `?? ""` kończył się dopiero na wywołaniu API
(cichy EMPTY_RESPONSE 422); miejsce wybrano architektonicznie (ten plik jest edytowany w KROKU 1,
to konfiguracyjna ochrona ścieżki; registry w KROKU 5 sformalizuje regułę globalnie).
Dowód: nowy blok w handlerze; zachowanie bez klucza = 503 przed jakimkolwiek wywołaniem zewnętrznym.

### D-2026-08-18/4 — Lokalizacja dokumentacji: `benedictum-mobile/docs/`
Decyzja: ARC.md, DECISIONS_LOG.md, CHECKPOINTS.md w repo aplikacji, nie w DCI_HANDOFFS.
WHY: dokumentacja opisuje kod aplikacji i jest wersjonowana razem z nim (spójna historia zmian,
odnajdywalna dla każdego pracującego w repo); DCI_HANDOFFS/DECISIONS.md to międzyagentowy rejestr
Operatora w innym repo (Backup_DCI) — nie duplikujemy, możemy się odwoływać.

### D-2026-08-18/5 — Testy regresyjne wymagają `--node-modules-dir=none --cached-only`
Decyzja (techniczna): testy importujące `index.ts` uruchamiane z tymi flagami; gemini-proxy
dodatkowo z `--no-check` (transpilowany JS ma 31 wcześniej istniejących błędów typów — FACT z F0).
WHY: repo nie ma deno.json/node_modules; npm deps rozwiązywane z globalnego cache;
type-check full graph wykrywa istniejące błędy typu w transpilowanym gemini-proxy — nie są one
regresją KROKU 1 (obsługa produkcyjna Supabase i tak ich nie sprawdza).
Dowód: przebiegi testów poniżej w CHECKPOINTS.md.

## KROK 0 (2026-08-17/18) — decyzje Operatora przeniesione do realizacji

- **F0:** wykreślony jako osobny krok; typowany gemini adapter powstaje jako nowy kod TS w KROKU 4
  (w historii gita nigdy nie było typowanego TS — pierwszy commit 8c895d1 to już transpilowany JS).
- **Router:** wariant A (bez osobnej warstwy); interfejs `TrackRouter` deklarowany w core (KROK 3),
  `StaticOrderRouter` jako jedyna implementacja (KROK 5). FUTURE: strategie health/cost/canary.
- **KROK 1 bez `_shared/`:** ekstrakcja `_shared/` + test importów → KROK 2.
- **R7:** utwardzenie klienta (`report.dart`) → KROK 7 (razem z przejściem na llm-gateway);
  backend = enforcement, klient = defensive validation.
- **userId:** NIE wycinamy; dokumentujemy przepływ (OpenRouter otrzymuje `user`); brak polityki teraz.
- **Core typy v1.1 (D8):** tylko potrzebne typy (Part/Content, CanonicalError, ExecutionTrack,
  TaskSpec, CapabilityId, kontrakty, ArtifactRef, deklaracja IArtifactStore) → KROK 3.
- **Kontrakt tracków nośnikowo-niezależny (D6):** JSON-secret teraz; tabela FUTURE.
- **Konkurs (RevenueCat Shipaton 2026):** checkpoint zewnętrzny; zmiana regulaminu → STOP → analiza.