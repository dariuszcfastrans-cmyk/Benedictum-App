# T1 CLOSURE — STT semantyka (final_result → finalResult) + fallback cloud

> Status: **CLOSED 2026-08-20** (A3.6 PASS end-to-end, commit `6a33de0`).
> Charakter: dokument uzupełniający (housekeeping po T1). Nie przepisuje historii
> (ARC/CHECKPOINTS/DECISIONS_LOG pozostają aktualne dla K1–K9); zapisuje wyłącznie
> ustalenia wynikające z zakończonego etapu T1.

---

## 1. Co zostało zbadane (T1-DART / T1-KOTLIN / T1-SEMANTYKA)

Instrumentacja diagnostyczna (logi `T1DART-*` w Dart, `T1KOTLIN-*` w pluginie) na
fizycznym urządzeniu Samsung Galaxy S23 Ultra (`SM-S918B`, serial `R5CWA232ZPF`),
ścieżka: mikrofon → `speech_to_text` 7.4.0 (pub-cache) → `VoiceService` (hybryda R1-C)
→ pole input `chat_screen.dart`.

Badane zjawiska (3–4 przebiegi, realna mowa):
- `onPartialResults` z kluczem `final_result=true` — ostatni partial GoogleTTS/Soda
  z pełną transkrypcją i `confidence_scores` (1× na sesję).
- `onResults` przychodzący z **pustym Bundle** (`keys=0`) po final — anomalia GoogleTTS;
  deterministyczna (3/3 przebiegi z mową).
- Mapowanie plugin: `isFinal→finalResult`, `finalResult→intermediate` (błędne),
  `else→partial` — skutek: final nigdy nie docierał do Dart jako `finalResult`
  (plugin mapował go jako intermediate, podwójne emitowanie w `_notifyResults`).

## 2. Co zostało potwierdzone

- **Korekta mapowania w pluginie** (pub-cache `SpeechToTextPlugin.kt`, linie ~477-482):
  ```kotlin
  val hasRecognizedWords = !userSaid.firstOrNull().isNullOrBlank()
  val resultType = if ((isFinal || finalResult) && hasRecognizedWords) {
      ResultType.finalResult
  } else {
      ResultType.partial
  }
  ```
  Działanie potwierdzone w logcat 3× (10:37, 13:06, 16:37): `final_result=true` →
  `EMIT resultType=2 (finalResult)`; pusty `onResults` → `EMPTY_PATH` (NIE nadpisuje
  wysłanego finala).
- **Fallback cloud przy zbyt krótkim on-device** (voice_service.dart:
  `minOnDeviceWordCount = 4`): on-device potrafi obciąć frazę do ~3 słów i zwrócić je
  jako finalResult — progiem jest liczba słów; 1–3 słowne wyniki (szum / obcięcie)
  uruchamiają jeden automatyczny fallback do chmury systemowej (R1-C).
- **Przepływ final→Dart→UI**: `_listenOnce` kończy `Completer` przed timeoutem,
  `chat_screen` ustawia transkrypcję w polu input. Dowód konsola `[T1DART-C1..D2]`.
- **A3.6 end-to-end PASS** (16:37): fraza `"mam gotowe mvp i szukam inwestora kto jest"`,
  słowa-klucze `[gotowe, mvp, szukam, inwestora]` — **4/4 dopasowane**,
  `lastSttMode=SttMode.onDevice` (audio NIE opuściło urządzenia), flow → TTS pełny cykl.

## 3. Commit zamykający etap

| Commit | Zakres |
|---|---|
| `6a33de0` | `[A3.6] Real voice end-to-end 1/1 PASS (S23 Ultra)…` — `voice_service.dart` (fallback cloud + instrumentacja), `chat_screen.dart` (instrumentacja), `integration_test/e2e_voice_real_test.dart` (nowy test A3.6) |

- Working tree po commicie `6a33de0`: **czysty**. **Stan na 2026-08-20 (po housekeeping):**
  niecommitowane zmiany **dokumentacyjne** — niniejszy `T1_CLOSURE.md` (nowy) oraz
  `data_safety.md` (doprecyzowanie progu `minOnDeviceWordCount`); decyzja o commicie
  należy do Operatora.
- **UWAGA (REPRODUCIBILITY RISK):** korekta `SpeechToTextPlugin.kt` (pub-cache) NIE
  jest częścią commita `6a33de0` — plugin jest w `~/.pub-cache/hosted/pub.dev/
  speech_to_text-7.4.0/`, poza repozytorium. Aby APK nadal zawierał korektę, pub-cache
  musi pozostać zmodyfikowany. To celowo NIE rozwiązane — do późniejszej decyzji
  (vendor / dependency_overrides / PR do pluginu). Szczegóły: sekcja 5.

## 4. Dowody (artefakty lokalne, poza repo)

| Ślad | Plik | Co dowodzi |
|---|---|---|
| Logcat PASS | `/tmp/opencode/t1cf3_logcat.txt` | `EMIT resultType=2` + `EMPTY_PATH` (linie 12655-12675) |
| Konsola PASS | `/tmp/opencode/t1cf3_console.txt` | C1→C2→C3→D2, A3.6 PASS, keywords 4/4 |
| Logcat (analogicznie) | `/tmp/opencode/t1semantics_logcat*.txt` | powtórka 10:37 / 13:06 |
| Konsola (analogicznie) | `/tmp/opencode/t1semantics_test*_console.txt` | przebiegi wcześniejsze |

## 5. Stan zmian i backupów

- **W repo (commit `6a33de0`)**: `voice_service.dart` (próg 4 + logi), `chat_screen.dart`
  (logi), `e2e_voice_real_test.dart` (test).
- **POZA repo (pub-cache, NIE wersjonowane)**: `SpeechToTextPlugin.kt` — korekta
  semantyczna + instrumentacja `T1KOTLIN`. Ryzyko reprodukowalności: reinstalacja
  pub-cache / `flutter clean` + rebuild nadpisze plugin i cofnie korektę.
- **Backupy** (nienaruszone):
  - `/tmp/opencode/t1dart_backup/` — stan Dart sprzed instrumentacji T1-DART (5 plików)
  - `/tmp/opencode/t1kotlin_backup/` — `SpeechToTextPlugin.kt` (sprzed T1-KOTLIN)
  - `/tmp/opencode/t1semantics_backup/` — `SpeechToTextPlugin.kt` (sprzed korekty semantycznej)
  - `/tmp/opencode/t1cloudfallback_backup/` — `voice_service.dart` (sprzed fallbacku/przeróbki)
- Wolę operacyjne (do decyzji, NIE wykonane): czy zapisać backupu do trwałego miejsca
  w repo (np. `docs/backups/`) — w chwili zamknięcia są tylko w `/tmp`.

## 6. UNKNOWN / OPEN (NIE zamieniać w fakt)

- **U-T1-01** Fallback cloud `<4 słowa on-device` (`[T1DART-C3b]` → `[C4]` → `SttMode.cloud`)
  — **nieudowodniony end-to-end** (w przebiegu PASS on-device zwróciło 8 słów, fallback
  nie wystąpił; szum "tak słuchaj ja" (3 słowa) w przebiegu 16:33 został odfiltrowany,
  ale cloud nie był wykonywany, bo on-device nie było <4 w scenariuszach testowych).
- **U-T1-02** Trwałe wersjonowanie korekty `SpeechToTextPlugin.kt` — **nierozwiązane**
  (techniczny dług / ryzyko reprodukowalności; opcje: vendor, dependency_overrides,
  PR do pluginu, dokumentacja).
- **U-T1-03** Instrumentacja `T1DART`/`T1KOTLIN` (debugPrint) wcommittowana w `6a33de0`
  oraz w pluginie pub-cache — decyzja: zostawić (logi pomocnicze) czy wyczyścić.
- **U-T1-04** Zmienność jakości rozpoznawania on-device (obcięcia ~3 słów vs pełna fraza)
  — progiem `<4` zarządzane, ale nie ma statystyki wielokrotnych przebiegów.

## 7. MiniMax M3 — READ-ONLY REVIEW (gotowość)

Benedictum Mobile jest gotowe do niezależnego read-only review. Stan reprodukowalny na
`master@6a33de0` + zmodyfikowany pub-cache `speech_to_text-7.4.0` (korekta pluginu).
Recenzent powinien wiedzieć o U-T1-02 (plugin poza repo) — bez tego stan kodu Dart jest
niespójny z APK działającym na urządzeniu.