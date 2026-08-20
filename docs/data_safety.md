# Data Safety — mapa odpowiedzi do formularza (Google Play / Galaxy Store)

_Ostatnia aktualizacja: 2026-08-20 (VOICE HARDENING: hybryda on-device + cloud R1-C)_
_Dokument roboczy K9 (B3): przenieść 1:1 do formularza w konsoli._

## Google Play — Data safety form

### 1. Czy aplikacja gromadzi dane użytkownika? → **TAK**

### 2. Jakie dane są gromadzone (kategorie i typy)

| Kategoria | Typ | Deklaracja |
|---|---|---|
| Dane osobiste | Adres e-mail | TAK |
| Dane osobiste | Nazwa (wyświetlana) | TAK |
| Aktywność w aplikacji | Interakcje w aplikacji | TAK (treść sesji/raporty) |
| Aktywność w aplikacji | Wyszukiwania | NIE |
| Aktywność w aplikacji | Odwiedzone strony | NIE |
| Wiadomości | E-maile | NIE (brak wysyłki z aplikacji) |
| Wiadomości | Inne wiadomości w aplikacji | TAK (treść rozmów z trenerami AI) |
| Zdjęcia/wideo | Zdjęcia, filmy | NIE |
| Zdjęcia/wideo | Audio | NIE |
| Dane finansowe | Historia zakupów | TAK (status subskrypcji przez RevenueCat/Play) |
| Dane finansowe | Karty płatnicze/inne | NIE (obsługuje Google Play) |
| Informacje o zdrowiu/fitness | | NIE |
| Lokalizacja | | NIE |
| Dziennik/dzienniki aktywności | | NIE |
| Identyfikatory | Identyfikatory urządzeń | TAK (OneSignal — powiadomienia push) |
| Identyfikatory | Identyfikatory użytkownika | TAK (Supabase user id) |
| Identyfikatory | Identyfikatory reklamowe | NIE |

### 3. Czy dane są udostępniane podmiotom trzecim? → **TAK**

| Typ danych | Kto | Cel |
|---|---|---|
| Treść rozmów AI | OpenRouter + dostawcy modeli (przez OpenRouter) | generowanie odpowiedzi |
| Status subskrypcji | RevenueCat / Google Play | weryfikacja zakupów |
| Identyfikator urządzenia | OneSignal | powiadomienia push |
| Konto | Supabase | autoryzacja i przechowywanie |

> NIE dla: sprzedaży danych, udostępniania celom marketingowym.

### 4. Zasady bezpieczeństwa danych

| Pytanie | Odpowiedź |
|---|---|
| Czy dane są szyfrowane w transmisji? | **TAK** (TLS do Supabase/OpenRouter/RevenueCat) |
| Czy dane są szyfrowane w spoczynku? | **TAK** (standard dostawców: Supabase, OpenRouter) |
| Czy użytkownik może zażądać usunięcia danych? | **TAK** (w aplikacji: Ustawienia → Usuń konto; opis w polityce §6) |
| Czy użytkownik może złożyć wniosek o dane? | **TAK** (kontakt w polityce §7) |

### 5. Oświadczenie o zasadach

- Polityka prywatności URL: **<URL — do wklejenia po publikacji; plik źródłowy: docs/privacy-policy.md>**
- Deklaracja zgodności: aplikacja ma funkcję usuwania konta i politykę prywatności.

## Galaxy Store — zależnie od wymagań Samsung (2025)

- Data Safety wymagane od 24.09.2025.
- Ta sama polityka + te same odpowiedzi jak wyżej; Samsung nie sponsoruje
  kategorii Career Coaching, ale wymogi są globalne dla sklepu.
- Commercial Seller: wymagane do IAP (wniosek złożony ~21.08 — status do sprawdzenia).

## Uwagi do aktualizacji przed wysłaniem formularza

1. Wkleić realny URL polityki (po publikacji GitHub/strony — decyzja D6).
2. Uzupełnić kontakt e-mail w docs/privacy-policy.md (§7).
3. Jeśli decyzja D7 → płatny model: zaktualizować opis dostawców, bo zmienia się
   praktyka treningu (free endpoints = trening domyślnie ON).

## Voice (A3.2/A3.3) — hybryda on-device + cloud (R1-C, VOICE HARDENING)

- Głosowe wprowadzanie (STT) działa **hybrydowo**: najpierw próbuje rozpoznania
  **na urządzeniu** (Android: `onDevice:true` + `isOnDeviceRecognitionAvailable`;
  iOS: `onDevice:true`). Fallback do chmury następuje **jawnie** (speech_to_text
  createSpeechRecognizer bez `onDevice`), gdy on-device zwróci puste/nieudane
  rozpoznanie **lub wynik krótszy niż `minOnDeviceWordCount = 4` słowa** (T1:
  on-device potrafi obciąć frazę do ~3 słów i podać je jako finalResult — taki
  wynik jest traktowany jako niekompletny). Tryb ostatniego rozpoznania jest
  raportowany (`lastSttMode`).
- **Audio może zatem opuścić urządzenie w scenariuszu fallbacku cloud** — po
  transkrypcji nie jest przechowywane po stronie serwera przez aplikację.
  TTS (odtwarzanie odpowiedzi) działa na urządzeniu (Android TextToSpeech).
- Do LLM Gateway trafia wyłącznie **tekst** transkrypcji (ten sam, który użytkownik
  mógłby wpisać ręcznie). Nie jest on nową kategorią danych.
- Uprawnienie RECORD_AUDIO jest wymagane przez system; aplikacja prosi o nie
  dopiero w momencie pierwszego użycia 🎙 (degradacja do trybu tekstowego bez zgody).
- **Deklaracja sklepowa**: audio NIE jest wysyłane przez aplikację jako plik i nie
  jest gromadzone; ale przy fallbacku cloud audio trafia do usługi rozpoznawania
  mowy platformy (Android RecognizerIntent / iOS SFSpeech). W formularzu danych
  sklepu opisz to jako przetwarzanie przez zewnętrzne usługi rozpoznawania mowy,
  a nie jako „audio NIE opuszcza urządzenia".