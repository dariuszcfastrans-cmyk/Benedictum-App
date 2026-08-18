# Polityka Prywatności — Benedictum

_Ostatnia aktualizacja: 2026-08-18 (A3: voice on-device)_
_Odpowiedzialność prawna: DCI Veridictum Lab / Dariusz Cedro_
_Kontakt: (do uzupełnienia przez Operatora przed publikacją)_

## 1. Zakres

Niniejsza polityka opisuje, jak aplikacja **Benedictum** („aplikacja”) gromadzi,
wykorzystuje i chroni dane użytkowników. Aplikacja jest trenerem rozmów AI
(negocjacje / prezentacje / kariera) z funkcją subskrypcji.

## 2. Dane, które gromadzimy

### 2.1. Konto i uwierzytelnianie
- Adres e-mail i hasło (uwierzytelnianie przez Supabase Auth).
- Metadane profilu: nazwa wyświetlana, preferowany język (opcjonalnie).

### 2.2. Sesje treningowe
- Treść rozmów z trenerami AI (scenariusze, wypowiedzi użytkownika).
- Wygenerowane raporty: mocne strony, luki, wskazówki, ocena.
- Metadane sesji (scenariusz, status, czas utworzenia).

### 2.3. Subskrypcje i płatności
- Status subskrypcji Pro (przez RevenueCat; płatności obsługuje Google Play).
- Nie gromadzimy danych kart płatniczych — obsługuje je Google Play.

### 2.4. Dane techniczne
- Dziennik zużycia limitów (rate-limit) w celu ochrony przed nadużyciami.
- Identyfikator push (OneSignal) wyłącznie w celu powiadomień.

### 2.5. Głos (voice)
- Mikrofon jest używany wyłącznie do **głosowego wpisywania wiadomości**.
- Rozpoznawanie mowy (STT) i synteza odpowiedzi (TTS) odbywają się **w całości
  na urządzeniu użytkownika**. Nagrania głosowe i audio NIE są przesyłane,
  gromadzone ani przechowywane przez aplikację ani podmioty trzecie.
- Do serwerów trafia wyłącznie tekst transkrypcji — ten sam, który użytkownik
  mógłby wpisać ręcznie (por. §2.2).

## 3. Jak wykorzystujemy dane

- **Świadczenie usługi:** generowanie odpowiedzi trenerów AI i raportów.
- **Autoryzacja i bezpieczeństwo:** uwierzytelnianie, ochrona przed nadużyciami.
- **Subskrypcje:** weryfikacja i przywracanie zakupów.
- **Powiadomienia:** wyłącznie wtedy, gdy użytkownik je włączy.

**Dane nie są sprzedawane ani udostępniane podmiotom trzecim w celach marketingowych.**

## 4. Dostawcy usług (przetwarzanie danych)

| Podmiot | Rola | Dane |
|---|---|---|
| Supabase (US/UE) | autoryzacja, baza danych, funkcje serwerowe | konto, sesje, raporty |
| OpenRouter (US) | router modeli AI | treść zapytań i odpowiedzi AI |
| Dostawcy modeli AI przez OpenRouter | generowanie odpowiedzi | treść zapytań/odpowiedzi |
| RevenueCat | subskrypcje | status subskrypcji |
| Google Play | płatności, dystrybucja | transakcje |
| OneSignal | powiadomienia push | identyfikator urządzenia |

Wybór modelu AI odbywa się **po stronie serwera**; aplikacja nie przechowuje
kluczy API dostawców AI.

## 5. Przechowywanie i bezpieczeństwo

- Dane przechowywane w bazie Supabase (szyfrowanie w transmisji TLS, szyfrowanie
  w spoczynku zgodnie ze standardami dostawcy).
- Klucze API trzymane wyłącznie po stronie serwera (Supabase Secrets), nigdy
  w aplikacji.
- Dostęp do danych ograniczony do zalogowanego użytkownika (Row Level Security).

## 6. Retencja i usuwanie

- Dane przechowywane tak długo, jak aktywne jest konto.
- **Usuwanie konta:** użytkownik może w każdej chwili usunąć konto
  (Ustawienia → Usuń konto). Usunięcie jest trwałe i nieodwracalne:
  kasuje konto, sesje, raporty i metadane.
- Logi rate-limit usuwane wraz z kontem.

## 7. Prawa użytkownika

W zależności od jurysdykcji (m.in. RODO) użytkownikowi przysługują prawa do:
- dostępu, poprawiania i przenoszenia danych,
- usunięcia danych (por. §6),
- wycofania zgody i sprzeciwu wobec przetwarzania,
- złożenia skargi do organu nadzorczego.

**Kontakt w sprawach danych:** (adres e-mail Operatora — do uzupełnienia).

## 8. Zmiany polityki

Zmiany publikowane pod tym adresem z aktualizacją daty. Dalsze korzystanie
z aplikacji po zmianie oznacza ich akceptację.

## 9. Dane dzieci

Aplikacja nie jest kierowana do dzieci poniżej 13 lat i nie zbiera świadomie
ich danych.