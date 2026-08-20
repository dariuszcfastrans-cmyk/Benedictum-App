import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, visibleForTesting;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../config/locale_controller.dart';
import 'interfaces/i_voice_service.dart';

/// Implementacja IVoiceService na Android/iOS (A3.2/A3.3, R1-C, R2, R-TTS).
///
/// STT (R1-C — HYBRYDA):
///   preferowane rozpoznawanie on-device (audio NIE opuszcza urządzenia);
///   jeżeli on-device nie daje wyniku (niedostępne/błąd/cisza) → JEDNO
///   automatyczne ponowienie z rozpoznawaniem sieciowym (cloud, tryb systemu).
///   O faktycznym trybie decyduje platforma; [lastSttMode] raportuje wynik.
///   Audio może opuścić urządzenie WYŁĄCZNIE w ostatniej próbie cloud.
///
/// TTS (R-TTS): przed syntezą [speak] usuwa formatowanie Markdown, aby TTS
/// nie odczytywał znaczników (**, -, #, 1.) jako części wypowiedzi.
/// Docelowa architektura displayContent/ttsContent — przyszły etap (parked).
///
/// Język (R2): STT i TTS używają JĘZYKA ROZMOWY ustawionego przez użytkownika
/// (setConversationLanguage), niezależnego od języka systemu/roamingu/UI.
class VoiceService implements IVoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _sttInitialized = false;
  bool _ttsInitialized = false;
  bool _ttsSpeaking = false;
  String? _sttLocaleId;
  String _ttsLocaleId = 'en-US';
  SttMode _lastSttMode = SttMode.none;

  /// Ustawia język rozmowy dla STT i TTS (R2). Brak zmiany → nadal działa
  /// poprzedni język aż do ponownego transcribe/speak.
  @override
  void setConversationLanguage(ConversationLanguage language) {
    _sttLocaleId = language.ttsLocaleId;
    _ttsLocaleId = language.ttsLocaleId;
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
  SttMode get lastSttMode => _lastSttMode;

  @override
  Future<bool> initStt() async {
    if (_sttInitialized) return true;
    if (!isSttSupported) return false;
    _sttInitialized = await _speech.initialize(
      finalTimeout: const Duration(seconds: 10),
      debugLogging: true,
    );
    return _sttInitialized;
  }

  @override
  Future<bool> initTts() async {
    if (_ttsInitialized) return true;
    if (!isTtsSupported) return false;
    final ok = await _configureTtsLanguage(_ttsLocaleId);
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

  /// Pojedyncza próba nasłuchiwania w podanym trybie (on-device / cloud).
  /// Zwraca transkrypcję (pusty String = brak wyniku). Rzuca wyjątek tylko
  /// przy twardym błędzie nasłuchiwania (np. brak zgody na mikrofon).
  Future<String> _listenOnce({
    required bool onDevice,
    required int timeoutSeconds,
  }) async {
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
        onDevice: onDevice,
        partialResults: true,
        cancelOnError: true,
      ),
      onResult: (result) {
        debugPrint('[T1DART-C1] voice_service onResult final=${result.finalResult} '
            'type=${result.resultTypeValue} words="${result.recognizedWords}" '
            'empty=${result.recognizedWords.isEmpty} completerCompleted=${completer.isCompleted}');
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
    debugPrint('[T1DART-C2] _listenOnce zakończone onDevice=$onDevice '
        'result="$result" empty=$result.isEmpty completed=${completer.isCompleted} '
        'fallback="$fallback" isListening=$_speech.isListening');

    if (!_speech.isListening) return result;
    await _speech.stop();
    return result;
  }

  /// Minimalna liczba słów wyniku on-device akceptowana jako kompletna.
  /// On-device (Soda) potrafi obciąć frazę do pierwszych ~3 słów i zwrócić
  /// je jako finalResult — byłoby to mylnie traktowane jako pełny wynik.
  /// Próg 4 słów: wyniki 1-3 słowne (typowy szum tła / obcięta fraza) są
  /// uznawane za niekompletne i wymuszają fallback do chmury systemowej (R1-C).
  static const int minOnDeviceWordCount = 4;

  @override
  Future<String> transcribe({int timeoutSeconds = 8}) async {
    // R1-C: HYBRYDA — najpierw on-device (audio nie opuszcza urządzenia).
    String result = '';
    try {
      result = await _listenOnce(onDevice: true, timeoutSeconds: timeoutSeconds);
    } catch (_) {
      result = '';
    }
    final onDeviceWords =
        result.trim().isEmpty ? 0 : result.trim().split(RegExp(r'\s+')).length;
    debugPrint('[T1DART-C3] transcribe po onDevice wynik="$result" empty=$result.isEmpty '
        'words=$onDeviceWords minWords=$minOnDeviceWordCount');
    if (onDeviceWords >= minOnDeviceWordCount) {
      _lastSttMode = SttMode.onDevice;
      return result;
    }
    debugPrint('[T1DART-C3b] onDevice zbyt krótkie ($onDeviceWords < '
        '$minOnDeviceWordCount słów) → fallback cloud');

    // Jawny fallback do chmury systemowej (on-device niedostępne / cisza /
    // zbyt krótki wynik).
    try {
      result = await _listenOnce(onDevice: false, timeoutSeconds: timeoutSeconds);
    } catch (_) {
      result = '';
    }
    debugPrint('[T1DART-C4] transcribe po cloud wynik="$result" empty=$result.isEmpty');
    _lastSttMode = SttMode.cloud;
    return result;
  }

  @override
  Future<void> cancelListening() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }

  /// Usuwa formatowanie Markdown, aby TTS nie czytał znaczników jako treści
  /// (R-TTS). Zachowuje właściwy tekst; nie dotyka nowych linii.
  /// Obsługuje: **bold**, *italic*, `code`, nagłówki #, listy -/1., > quote,
  /// linki [tekst](url), ~~przekreślenie~~.
  @visibleForTesting
  static String stripMarkdown(String text) {
    if (text.isEmpty) return text;
    var t = text;
    // Odnośniki Markdown: [tekst](url) → tekst (najpierw, by nie złamać linków).
    t = t.replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m[1]!);
    // Przekreślenie ~~x~~.
    t = t.replaceAllMapped(RegExp(r'~~([^~]+)~~'), (m) => m[1]!);
    // Pogrubienie i kursywa: **x** / __x__ / *x* / _x_.
    t = t.replaceAllMapped(
        RegExp(r'(\*\*|__)(.+?)\1'), (m) => m[2]!);
    t = t.replaceAllMapped(RegExp(r'(\*|_)(.+?)\1'), (m) => m[2]!);
    // Kod inline `x`.
    t = t.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1]!);
    // Nagłówki na początku linii.
    t = t.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    // Listy i cytaty na początku linii.
    t = t.replaceAll(
        RegExp(r'^\s*(?:[-*+]\s+|>\s+|[0-9]+\.\s+)', multiLine: true), '');
    // Pozostałe pojedyncze gwiazdki na brzegach słów (np. separator).
    t = t.replaceAll('*', '');
    return t.trim();
  }

  @override
  Future<bool> speak(String text) async {
    if (!isTtsSupported || text.trim().isEmpty) return false;
    if (!_ttsInitialized) {
      await initTts();
    }
    // R-TTS: TTS czyta CZYSTY tekst — bez znaczników Markdown.
    final clean = stripMarkdown(text);
    if (clean.isEmpty) return false;
    _ttsSpeaking = true;
    final result = await _tts.speak(clean);
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