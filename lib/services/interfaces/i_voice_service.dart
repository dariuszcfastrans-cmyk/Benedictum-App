import '../../config/locale_controller.dart';

/// Tryb rozpoznawania użyty w ostatniej transkrypcji (R1-C — weryfikowalność).
enum SttMode {
  /// Przetwarzanie lokalne (on-device) — audio nie opuściło urządzenia.
  onDevice,

  /// Jawny fallback do chmury (on-device niedostępne lub puste).
  cloud,

  /// STT nie zostało jeszcze wykonane.
  none,
}

/// Interfejs usługi głosowej Benedictum (A3 — voice).
///
/// Voice jest wyłącznie warstwą komunikacyjną przed istniejącym mechanizmem
/// tekstowym: STT dostarcza String do pola tekstowego, TTS czyta String
/// z istniejącego Message.content. Silnik LLM pozostaje nietknięty.
///
/// STT (R1-C): preferowane rozpoznawanie on-device; jawny fallback do chmury
/// systemowej, gdy on-device jest niedostępne. O faktycznym trybie decyduje
/// platforma — [lastSttMode] raportuje wynik (weryfikowalność zachowania).
/// Audio może opuścić urządzenie WYŁĄCZNIE w trybie cloud (fallback).
abstract interface class IVoiceService {
  /// Czy platforma wspiera rozpoznawanie mowy (false na Web/desktop).
  bool get isSttSupported;

  /// Czy platforma wspiera syntezę mowy (false na Web).
  bool get isTtsSupported;

  /// Tryb STT użyty w ostatniej transkrypcji (R1-C). `none` przed pierwszą.
  SttMode get lastSttMode;

  /// Inicjalizacja STT (SpeechRecognizer). Zwraca false, gdy niedostępne.
  Future<bool> initStt();

  /// Inicjalizacja TTS (TextToSpeech). Zwraca false, gdy niedostępne.
  Future<bool> initTts();

  /// Ustawia język rozmowy dla STT i TTS (R2). Język rozmowy jest niezależną
  /// decyzją użytkownika — nie jest pobierany z systemu ani roamingu.
  void setConversationLanguage(ConversationLanguage language);

  /// Rozpoznaje mowę i zwraca transkrypcję (String). Wraca po pauzie
  /// użytkownika lub po [timeoutSeconds]. Pusty String = brak rozpoznania.
  /// Hybryda (R1-C): najpierw on-device; przy braku wyniku/błędzie — cloud.
  Future<String> transcribe({int timeoutSeconds = 8});

  /// Zatrzymuje bieżące rozpoznawanie (użytkownik anulował nagrywanie).
  Future<void> cancelListening();

  /// Odtwarza [text] głosem. [text] jest czyszczony z formatowania
  /// Markdown przed syntezą (R-TTS — TTS nie czyta znaczników).
  /// Zwraca true, gdy odtworzono.
  Future<bool> speak(String text);

  /// Zatrzymuje bieżące odtwarzanie (pauza/stop).
  Future<void> stopSpeaking();

  /// Czy trwa odtwarzanie.
  bool get isSpeaking;
}