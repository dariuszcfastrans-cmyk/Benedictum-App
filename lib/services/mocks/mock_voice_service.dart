import '../interfaces/i_voice_service.dart';

/// Mock IVoiceService (A3) — offline/do testów widget.
/// STT/TTS symulowane z opóźnieniem; nie dotyka sprzętu ani platformy.
class MockVoiceService implements IVoiceService {
  MockVoiceService({
    this.simulateSttFailure = false,
    this.transcriptOverride = 'To jest przykładowa transkrypcja głosowa.',
  });

  /// Gdy true — transcribe() zwraca pusty String (symulacja braku rozpoznania).
  final bool simulateSttFailure;

  /// Tekst zwracany przez transcribe() (chyba że simulateSttFailure).
  final String transcriptOverride;

  bool _ttsSpeaking = false;

  @override
  bool get isSttSupported => true;

  @override
  bool get isTtsSupported => true;

  @override
  bool get isSpeaking => _ttsSpeaking;

  @override
  Future<bool> initStt() async => true;

  @override
  Future<bool> initTts() async => true;

  @override
  Future<String> transcribe({int timeoutSeconds = 8}) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
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