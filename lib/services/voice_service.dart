import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'interfaces/i_voice_service.dart';

/// Implementacja IVoiceService na Android/iOS (A3.2/A3.3).
///
/// STT: Android SpeechRecognizer / iOS Speech framework (pakiet speech_to_text)
/// — rozpoznawanie przez system; bez własnego klucza API.
/// TTS: systemowy TextToSpeech (pakiet flutter_tts) — głosy polskie/en.
///
/// Prywatność: całe przetwarzanie audio odbywa się NA URZĄDZENIU. Audio nigdy
/// nie opuszcza urządzenia i nie jest przechowywane. Do LLM Gateway trafia
/// wyłącznie tekst (ten sam, który użytkownik mógłby wpisać ręcznie).
class VoiceService implements IVoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _sttInitialized = false;
  bool _ttsInitialized = false;
  bool _ttsSpeaking = false;
  String? _sttLocaleId;

  /// Ustawia język rozpoznawania STT (ISO-639, np. 'pl-PL').
  void setSttLocale(String localeId) {
    _sttLocaleId = localeId;
  }

  /// Web nie wspiera SpeechRecognizer ani systemowego TTS — bezpieczna
  /// degradacja do trybu tekstowego.
  @override
  bool get isSttSupported => !kIsWeb;

  @override
  bool get isTtsSupported => !kIsWeb;

  @override
  bool get isSpeaking => _ttsSpeaking;

  @override
  Future<bool> initStt() async {
    if (_sttInitialized) return true;
    if (!isSttSupported) return false;
    _sttInitialized = await _speech.initialize(
      finalTimeout: const Duration(seconds: 10),
    );
    return _sttInitialized;
  }

  @override
  Future<bool> initTts() async {
    if (_ttsInitialized) return true;
    if (!isTtsSupported) return false;
    // Głos odpowiada bieżącemu językowi aplikacji; fallback en-US.
    final ok = await _configureTtsLanguage('pl-PL');
    _ttsInitialized = true;
    _tts.setCompletionHandler(() => _ttsSpeaking = false);
    _tts.setCancelHandler(() => _ttsSpeaking = false);
    _tts.setErrorHandler((_) => _ttsSpeaking = false);
    return ok;
  }

  Future<bool> _configureTtsLanguage(String lang) async {
    try {
      final languages = await _tts.getLanguages;
      if (languages is List && languages.contains(lang)) {
        await _tts.setLanguage(lang);
      } else {
        await _tts.setLanguage('en-US');
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> transcribe({int timeoutSeconds = 8}) async {
    if (!isSttSupported) return '';
    if (!_sttInitialized) {
      final ok = await initStt();
      if (!ok) return '';
    }

    final completer = Completer<String>();
    var finalText = '';

    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        listenFor: Duration(seconds: timeoutSeconds),
        pauseFor: const Duration(seconds: 3),
        localeId: _sttLocaleId,
        onDevice: false,
        partialResults: true,
        cancelOnError: true,
      ),
      onResult: (result) {
        if (result.finalResult) {
          if (!completer.isCompleted) {
            completer.complete(result.recognizedWords.trim());
          }
        } else {
          finalText = result.recognizedWords.trim();
        }
      },
    );

    // Fallback timeout: silnik nie zwrócił finalResult (np. cisza) → wracamy
    // z ostatnim częściowym wynikiem, jeśli istnieje.
    final fallback = finalText;
    final result = await completer.future.timeout(
      Duration(seconds: timeoutSeconds + 5),
      onTimeout: () => fallback,
    );

    if (!_speech.isListening) return result;
    await _speech.stop();
    return result;
  }

  @override
  Future<void> cancelListening() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }

  @override
  Future<bool> speak(String text) async {
    if (!isTtsSupported || text.trim().isEmpty) return false;
    if (!_ttsInitialized) {
      await initTts();
    }
    _ttsSpeaking = true;
    final result = await _tts.speak(text);
    return result == 1;
  }

  @override
  Future<void> stopSpeaking() async {
    if (_ttsSpeaking) {
      await _tts.stop();
      _ttsSpeaking = false;
    }
  }

  void dispose() {
    _speech.stop();
    _tts.stop();
  }
}