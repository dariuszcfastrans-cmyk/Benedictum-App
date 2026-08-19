import '../../config/locale_controller.dart';
import '../interfaces/i_voice_service.dart';

/// Mock IVoiceService (A3/R1-C/R2) — offline/do testów widget.
/// STT/TTS symulowane z opóźnieniem; nie dotyka sprzętu ani platformy.
///
/// Symulacja hybrydy (R1-C): [onDeviceUnavailable] ustawiony na true powoduje
/// przejście do fallbacku cloud (lastSttMode=cloud). Domyślnie on-device.
/// [lastSttMode] raportuje tryb ostatniej transkrypcji (weryfikowalność).
class MockVoiceService implements IVoiceService {
  MockVoiceService({
    this.simulateSttFailure = false,
    this.onDeviceUnavailable = false,
    this.transcriptOverride = 'To jest przykładowa transkrypcja głosowa.',
  });

  /// Gdy true — transcribe() zwraca pusty String (symulacja braku rozpoznania).
  final bool simulateSttFailure;

  /// Gdy true — on-device niedostępne; STT przechodzi na cloud (R1-C fallback).
  final bool onDeviceUnavailable;

  /// Tekst zwracany przez transcribe() (chyba że simulateSttFailure).
  final String transcriptOverride;

  bool _ttsSpeaking = false;
  SttMode _lastSttMode = SttMode.none;
  ConversationLanguage _language = ConversationLanguage.en;

  @override
  bool get isSttSupported => true;

  @override
  bool get isTtsSupported => true;

  @override
  bool get isSpeaking => _ttsSpeaking;

  @override
  SttMode get lastSttMode => _lastSttMode;

  @override
  void setConversationLanguage(ConversationLanguage language) {
    _language = language;
  }

  /// Język rozmowy ustawiony w ostatnim wywołaniu (dla asercji w testach).
  ConversationLanguage get conversationLanguage => _language;

  @override
  Future<bool> initStt() async => true;

  @override
  Future<bool> initTts() async => true;

  @override
  Future<String> transcribe({int timeoutSeconds = 8}) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (onDeviceUnavailable) {
      // Hybryda: on-device niedostępne → cloud (R1-C).
      _lastSttMode = SttMode.cloud;
    } else {
      _lastSttMode = SttMode.onDevice;
    }
    return simulateSttFailure ? '' : transcriptOverride;
  }

  @override
  Future<void> cancelListening() async {}

  @override
  Future<bool> speak(String text) async {
    if (text.trim().isEmpty) return false;
    _ttsSpeaking = true;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _ttsSpeaking = false;
    return true;
  }

  @override
  Future<void> stopSpeaking() async {
    _ttsSpeaking = false;
  }
}