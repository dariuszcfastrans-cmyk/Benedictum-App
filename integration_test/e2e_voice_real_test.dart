import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:benedictum_mobile/app.dart';
import 'package:benedictum_mobile/config/locale_controller.dart';
import 'package:benedictum_mobile/services/interfaces/i_voice_service.dart';
import 'package:benedictum_mobile/services/service_locator.dart';
import 'package:benedictum_mobile/services/supabase_api_service.dart';
import 'package:benedictum_mobile/services/supabase_auth_service.dart';
import 'package:benedictum_mobile/services/voice_service.dart';

// A3.6 REAL VOICE na fizycznym urządzeniu (Samsung Galaxy S23 Ultra / SM-S918B).
// PEŁNY łańcuch ONLINE z REALNĄ MOWĄ:
//   real voice (Operator mówi do mikrofonu) → STT hybryda (R1-C on-device→cloud)
//   → transkrypcja w polu input → flow (intake) → odpowiedź Coacha (llm-gateway)
//   → TTS (read-aloud).
//
// Różnica względem A3.5: A3.5 weryfikował łańcuch bez aktywnej mowy (cisza →
// kontrolowany fallback cloud). A3.6 wymaga REALNEGO GŁOSU — Operator mówi
// FRAZĘ w oknie nasłuchu po tapnięciu mikrofonu.
//
// Uruchomienie (sekrety z env HOSTA, NIGDY nie w repo):
//   set -a; . ~/.env.dci; set +a
//   flutter test integration_test/e2e_voice_real_test.dart \
//     -d <SERIAL> \
//     --dart-define=SUPABASE_URL="$SUPABASE_URL" \
//     --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
//     --dart-define=TEST_EMAIL="$BENEDICTUM_TEST_EMAIL" \
//     --dart-define=TEST_PASSWORD="$BENEDICTUM_TEST_PASSWORD" \
//     --dart-define=VOICE_PHRASE="Mam gotowe MVP i szukam inwestora"
//
// WARUNEK TESTU: android.permission.RECORD_AUDIO przyznane wcześniej
// (`adb shell pm grant com.dci.benedictum.benedictum_mobile android.permission.RECORD_AUDIO`),
// gdyż systemowy Android permission prompt nie jest klikalny z poziomu testu.

const String kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const String kTestEmail = String.fromEnvironment('TEST_EMAIL');
const String kTestPassword = String.fromEnvironment('TEST_PASSWORD');
const String kVoicePhrase = String.fromEnvironment('VOICE_PHRASE');

/// Słowa-klucze do weryfikacji transkrypcji (ASR-tolerancja: ≥2 z 3).
/// Wyodrębniane z frazy (słowa ≥3 znaków, bez minimalnych stop-words).
/// Uwaga: `RegExp` w Dart nie wspiera `\p{L}` bez flagi unicode — jawna lista
/// znaków polskich zamiast klasy Unicode.
List<String> _keywords(String phrase) {
  const stop = {'mam', 'i', 'w', 'z', 'na', 'do', 'to', 'sie', 'jest'};
  return phrase
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9ąćęłńóśźż]+'))
      .where((w) => w.length >= 3 && !stop.contains(w))
      .toSet()
      .toList();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    LocaleController.instance.setConversationLanguage(ConversationLanguage.pl);
    LocaleController.instance.locale.value = const Locale('pl');
  });

  testWidgets('A3.6 Real Voice: realny głos → STT → flow → llm-gateway → TTS',
      (tester) async {
    // ---- Setup ONLINE (odpowiednik main() w trybie produkcyjnym) ----
    expect(kSupabaseUrl.isNotEmpty, isTrue,
        reason: 'Brak SUPABASE_URL (przekaż --dart-define).');
    expect(kSupabaseAnonKey.isNotEmpty, isTrue,
        reason: 'Brak SUPABASE_ANON_KEY (przekaż --dart-define).');
    expect(kTestEmail.isNotEmpty, isTrue,
        reason: 'Brak TEST_EMAIL (przekaż --dart-define).');
    expect(kTestPassword.isNotEmpty, isTrue,
        reason: 'Brak TEST_PASSWORD (przekaż --dart-define).');
    expect(kVoicePhrase.isNotEmpty, isTrue,
        reason: 'Brak VOICE_PHRASE (przekaż --dart-define).');

    final keywords = _keywords(kVoicePhrase);
    debugPrint('A3.6: fraza="$kVoicePhrase" słowa-klucze=$keywords');
    expect(keywords.length, greaterThanOrEqualTo(2),
        reason: 'FRAZA zbyt krótka — potrzeba ≥2 słów-kluczy do weryfikacji.');

    await sb.Supabase.initialize(
        url: kSupabaseUrl, publishableKey: kSupabaseAnonKey);
    ServiceLocator.register(
      authService: SupabaseAuthService(),
      apiService: SupabaseApiService(),
      voiceService: VoiceService(),
    );

    // ---- Splash → Auth ----
    await tester.pumpWidget(BenedictumApp());
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(find.text('Przejdź dalej'), findsOneWidget,
        reason: 'Splash nie wyświetlił przycisku startu.');
    await tester.tap(find.text('Przejdź dalej'));
    await tester.pumpAndSettle();

    // ---- Realne logowanie ----
    expect(find.text('Logowanie'), findsWidgets);
    await tester.enterText(
        find.widgetWithText(TextField, 'E-mail'), kTestEmail);
    await tester.enterText(
        find.widgetWithText(TextField, 'Hasło'), kTestPassword);
    await tester.ensureVisible(find.text('Zaloguj'));
    await tester.tap(find.text('Zaloguj'));
    var onHome = false;
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (find.text('Pitch do inwestora').evaluate().isNotEmpty) {
        onHome = true;
        break;
      }
    }
    expect(onHome, isTrue, reason: 'Logowanie nie doprowadziło do Home.');
    await tester.pumpAndSettle();

    // ---- Home → Chat (scenariusz) ----
    await tester.tap(find.text('Pitch do inwestora'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byIcon(Icons.mic_none), findsOneWidget,
        reason: 'Przycisk mikrofonu (voice input) niewidoczny w czacie.');

    // ---- Intake: prawdziwa wiadomość → odpowiedź Coacha (llm-gateway) ----
    final inputField =
        tester.widget<TextField>(find.byType(TextField).first);
    inputField.controller!.text = 'Mam gotowe MVP i szukam inwestora.';
    await tester.pump(const Duration(milliseconds: 200));
    await tester.ensureVisible(find.text('Wyślij'));
    await tester.tap(find.text('Wyślij'));
    var coachReplied = false;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (find.text('Przejdź do analizy').evaluate().isNotEmpty) {
        coachReplied = true;
        break;
      }
    }
    expect(coachReplied, isTrue,
        reason: 'llm-gateway nie zwrócił odpowiedzi Coacha w intake (60s).');
    await tester.pumpAndSettle();

    // ---- REAL VOICE: mikrofon → Operator mówi FRAZĘ ----
    // Naciśnięcie mikrofonu uruchamia hybrydę STT (on-device → cloud). Po
    // zakończeniu transkrypcja trafia do pola input (chat_screen.dart:232) —
    // surowy wynik NIGDY nie jest wysyłany automatycznie.
    debugPrint('A3.6: >>> NACIŚNIĘTO MIKROFON — OPERATOR MÓWI TERAZ: "$kVoicePhrase" <<<');
    await tester.tap(find.byIcon(Icons.mic_none));
    await tester.pump(const Duration(milliseconds: 400));

    // REAL VOICE: czekamy na NIEpustą transkrypcję w polu input do 60s
    // (operator wypowiada frazę w oknie nasłuchu). Jednocześnie raportujemy
    // tryb STT (lastSttMode) — hybryda on-device → cloud.
    String transcribed = '';
    SttMode sttMode = SttMode.none;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (sttMode == SttMode.none) {
        sttMode = ServiceLocator.voiceService!.lastSttMode;
      }
      final fields = find.byType(TextField).evaluate().toList();
      if (i % 10 == 0 || i == 59) {
        final dump = fields.map((e) {
          final w = e.widget as TextField;
          final c = w.controller;
          return '[hash=${c == null ? 'null' : identityHashCode(c)} '
              'text="${c?.text ?? ''}"]';
        }).join(' ');
        debugPrint('[T1DART-D3] poll#$i TextField.count=${fields.length} $dump');
      }
      final inputAfterVoice =
          tester.widget<TextField>(find.byType(TextField).first);
      transcribed = inputAfterVoice.controller?.text ?? '';
      if (transcribed.isNotEmpty) {
        break;
      }
    }
    debugPrint('A3.6: lastSttMode=$sttMode');
    debugPrint('A3.6: transkrypcja w polu input = "$transcribed"');
    expect(sttMode, isNot(SttMode.none),
        reason: 'STT nie raportuje trybu (lastSttMode=none) po 60s.');
    expect(transcribed.isNotEmpty, isTrue,
        reason: 'Pole input puste po realnym głosie — brak transkrypcji.');
    final lower = transcribed.toLowerCase();
    final matched = keywords.where((k) => lower.contains(k)).toList();
    debugPrint('A3.6: dopasowane słowa-klucze=$matched (z ${keywords.length})');
    expect(matched.length, greaterThanOrEqualTo(2),
        reason: 'Transkrypcja nie zawiera ≥2 z ${keywords.length} '
            'słów-kluczy frazy: $keywords (rozpoznano: "$transcribed").');

    // ---- TTS (read-aloud): ikona głośnika przy odpowiedzi Coacha ----
    expect(find.byIcon(Icons.volume_up_outlined), findsWidgets,
        reason: 'Brak ikony read-aloud (TTS) przy odpowiedzi Coacha.');
    await tester.tap(find.byIcon(Icons.volume_up_outlined).first);
    await tester.pump(const Duration(milliseconds: 800));
    final voice = ServiceLocator.voiceService!;
    expect(voice.isSpeaking, isTrue,
        reason: 'TTS nie rozpoczął odtwarzania (isSpeaking=false).');
    await tester.tap(find.byIcon(Icons.stop_circle_outlined).first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(voice.isSpeaking, isFalse,
        reason: 'TTS nie zatrzymał odtwarzania (isSpeaking=true).');

    debugPrint(
        'A3.6: PASS — lastSttMode=$sttMode, transkrypcja="$transcribed", '
        'keywords=$matched/${keywords.length}, intake=OK, TTS=full cycle.');
  });
}