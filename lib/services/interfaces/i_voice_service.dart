/// Interfejs usługi głosowej Benedictum (A3 — voice).
///
/// Voice jest wyłącznie warstwą komunikacyjną przed istniejącym mechanizmem
/// tekstowym: STT dostarcza String do pola tekstowego, TTS czyta String
/// z istniejącego Message.content. Silnik LLM pozostaje nietknięty.
///
/// Wszystkie operacje są on-device (Android SpeechRecognizer + Android TTS);
/// audio NIE opuszcza urządzenia i NIE jest przechowywane.
abstract interface class IVoiceService {
  /// Czy platforma wspiera rozpoznawanie mowy (false na Web/desktop).
  bool get isSttSupported;

  /// Czy platforma wspiera syntezę mowy (false na Web).
  bool get isTtsSupported;

  /// Inicjalizacja STT (SpeechRecognizer). Zwraca false, gdy niedostępne.
  Future<bool> initStt();

  /// Inicjalizacja TTS (TextToSpeech). Zwraca false, gdy niedostępne.
  Future<bool> initTts();

  /// Rozpoznaje mowę i zwraca transkrypcję (String). Wraca po pauzie
  /// użytkownika lub po [timeoutSeconds]. Pusty String = brak rozpoznania.
  Future<String> transcribe({int timeoutSeconds = 8});

  /// Zatrzymuje bieżące rozpoznawanie (użytkownik anulował nagrywanie).
  Future<void> cancelListening();

  /// Odtwarza [text] głosem. Zwraca true, gdy odtworzono.
  Future<bool> speak(String text);

  /// Zatrzymuje bieżące odtwarzanie (pauza/stop).
  Future<void> stopSpeaking();

  /// Czy trwa odtwarzanie.
  bool get isSpeaking;
}