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

// A3.5 E2E VOICE na fizycznym urządzeniu (Samsung Galaxy S23 Ultra / SM-S918B).
// PEŁNY łańcuch ONLINE (prawdziwy backend):
//   Supabase init → ServiceLocator (realne usługi) → Splash → Auth (realne konto
//   testowe z --dart-define) → Home → Chat → Intake (prawdziwy llm-gateway) →
//   odpowiedź Coacha → TTS (read-aloud) → STT (hybryda on-device→cloud, R1-C).
//
// Uruchomienie (sekrety z env HOSTA, NIGDY nie w repo):
//   set -a; . ~/.env.dci; set +a
//   flutter test integration_test/e2e_voice_test.dart \
//     -d <SERIAL> \
//     --dart-define=SUPABASE_URL="$SUPABASE_URL" \
//     --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
//     --dart-define=TEST_EMAIL="$BENEDICTUM_TEST_EMAIL" \
//     --dart-define=TEST_PASSWORD="$BENEDICTUM_TEST_PASSWORD"
//
// Raport rozdziela: wykonano / przeszło / nie przeszło / ograniczenia.

const String kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const String kTestEmail = String.fromEnvironment('TEST_EMAIL');
const String kTestPassword = String.fromEnvironment('TEST_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Język rozmowy do testu: PL (STT/TTS locale pl-PL) — niezależny od systemu.
    LocaleController.instance.setConversationLanguage(ConversationLanguage.pl);
    LocaleController.instance.locale.value = const Locale('pl');
  });

  testWidgets('A3.5 E2E Voice: realny login → llm-gateway → TTS/STT hybryda (R1-C)',
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
    // Realne auth online: poczekaj na przekierowanie do Home (max ~20s).
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
    // Prawdziwe LLM: odpowiedź może potrwać (llm-gateway → Gemini/OpenRouter).
    var coachReplied = false;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(seconds: 1));
      // Po odpowiedzi Coacha pojawia się przycisk decyzji użytkownika.
      if (find.text('Przejdź do analizy').evaluate().isNotEmpty) {
        coachReplied = true;
        break;
      }
    }
    expect(coachReplied, isTrue,
        reason: 'llm-gateway nie zwrócił odpowiedzi Coacha w intake (60s).');
    expect(find.text('Mam gotowe MVP i szukam inwestora.'), findsOneWidget,
        reason: 'Wiadomość użytkownika niewidoczna po wysłaniu.');
    await tester.pumpAndSettle();

    // ---- TTS (read-aloud): ikona głośnika przy odpowiedzi Coacha ----
    expect(find.byIcon(Icons.volume_up_outlined), findsWidgets,
        reason: 'Brak ikony read-aloud (TTS) przy odpowiedzi Coacha.');
    await tester.tap(find.byIcon(Icons.volume_up_outlined).first);
    await tester.pump(const Duration(milliseconds: 800));
    final voice = ServiceLocator.voiceService!;
    expect(voice.isSpeaking, isTrue,
        reason: 'TTS nie rozpoczął odtwarzania (isSpeaking=false).');
    // Zatrzymaj odtwarzanie (ikona zmienia się na stop).
    await tester.tap(find.byIcon(Icons.stop_circle_outlined).first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(voice.isSpeaking, isFalse,
        reason: 'TTS nie zatrzymał odtwarzania (isSpeaking=true).');

    // ---- STT (hybryda R1-C): mikrofon → transkrypcja → lastSttMode ----
//    Na fizycznym urządzeniu bez aktywnego głosu test weryfikuje łańcuch:
//    on-device próba → ew. cloud fallback → wynik (pusty przy ciszy). Tryb
//    ostatniego rozpoznania jest raportowany (lastSttMode) — dowód R1-C.
//    WARUNEK TESTU: android.permission.RECORD_AUDIO przyznane wcześniej przez
//    `adb pm grant ...` (systemowy Android permission prompt). Full transkrypcja
//    rzeczywistej mowy jest OSOBNYM dowodem (A3.6 — real voice test).
    // transcribe() wykonuje DWA nasłuchy (on-device ~13s + cloud ~13s),
    // więc czekamy do 30s na raport trybu.
    await tester.tap(find.byIcon(Icons.mic_none));
    await tester.pump(const Duration(milliseconds: 300));
    var sttReported = false;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (voice.lastSttMode != SttMode.none) {
        sttReported = true;
        break;
      }
    }
    expect(sttReported, isTrue,
        reason: 'STT nie raportuje trybu (lastSttMode=none) po 30s — hybryda nie działa.');
    // Jeżeli on-device rozpoznał tekst (mowa) — wynik niepusty; przy ciszy
    // fallback cloud kończy się pustym wynikiem (oczekiwane ograniczenie).
    debugPrint('A3.5: lastSttMode=${voice.lastSttMode}');
  });
}