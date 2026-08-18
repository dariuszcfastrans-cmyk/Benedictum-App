import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:benedictum_mobile/app.dart';
import 'package:benedictum_mobile/services/mocks/mock_voice_service.dart';
import 'package:benedictum_mobile/services/service_locator.dart';

/// Nawiguje od Splash do czatu wybranego scenariusza.
Future<void> _navigateToChat(WidgetTester tester) async {
  await tester.pumpWidget(BenedictumApp());
  // Przysunięcie czasu — timery fade-in Splash.
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pumpAndSettle();

  // Splash → Auth.
  await tester.tap(find.text('Przejdź dalej'));
  await tester.pumpAndSettle();

  // Auth → Home (logowanie mockowe).
  await tester.enterText(find.widgetWithText(TextField, 'E-mail'), 'a@b.com');
  await tester.enterText(find.widgetWithText(TextField, 'Hasło'), 'secret');
  await tester.tap(find.text('Zaloguj'));
  await tester.pumpAndSettle();

  // Home → Chat (scenariusz "Pitch do inwestora").
  await tester.tap(find.text('Pitch do inwestora'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Czat: faza intake zwraca 1 odpowiedź Coacha, analyze 3 person',
      (tester) async {
    await _navigateToChat(tester);

    // Intake: pierwsza wiadomość → tylko Coach.
    await tester.enterText(find.byType(TextField), 'Mam gotowe MVP.');
    await tester.tap(find.text('Wyślij'));
    await tester.pump();

    // Wiadomość użytkownika widoczna.
    expect(find.text('Mam gotowe MVP.'), findsOneWidget);

    // Czekamy na odpowiedź Coacha (1 × 500 ms).
    await tester.pump(const Duration(milliseconds: 800));

    // W intake odpowiada tylko Coach (1 odpowiedź, brak Krytyka/Optymisty).
    expect(find.textContaining('Coach'), findsOneWidget);
    expect(find.textContaining('Krytyk'), findsNothing);
    expect(find.textContaining('Optymista'), findsNothing);

    // Po zebraniu wypowiedzi użytkownika pojawia się przycisk przejścia do analizy.
    expect(find.text('Przejdź do analizy'), findsOneWidget);

    // Decyzja użytkownika: przejście do analyze.
    await tester.tap(find.text('Przejdź do analizy'));
    await tester.pump();

    // Analyze: wysłanie kolejnej wiadomości → 3 odpowiedzi person.
    await tester.enterText(find.byType(TextField), 'Proszę o pełną analizę.');
    await tester.tap(find.text('Wyślij'));
    await tester.pump();

    // Czekamy na odpowiedzi (3 × 500 ms).
    await tester.pump(const Duration(milliseconds: 1700));

    // Wszystkie 3 persony odpowiedziały.
    expect(find.textContaining('Krytyk'), findsOneWidget);
    expect(find.textContaining('Optymista'), findsOneWidget);
    expect(find.textContaining('Coach'), findsWidgets);
  });

  testWidgets('Czat: „Zakończ sesję" generuje raport i otwiera dynamiczny ReportScreen',
      (tester) async {
    await _navigateToChat(tester);

    // Intake: zbierzemy przynajmniej jedną wypowiedź użytkownika.
    await tester.enterText(find.byType(TextField), 'Mam gotowe MVP.');
    await tester.tap(find.text('Wyślij'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    // „Zakończ sesję" → getReport (mock 500 ms) → ReportScreen z raportem.
    await tester.tap(find.text('Zakończ sesję'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    // Dynamiczny raport: sekcje i ocena z kontraktu (Fala 2A).
    expect(find.text('Raport'), findsOneWidget);
    expect(find.text('Ocena ogólna'), findsOneWidget);
    expect(find.text('4/5'), findsOneWidget);
    expect(find.text('Mocne strony'), findsOneWidget);
    expect(find.text('Luki i ryzyka'), findsOneWidget);
    expect(find.text('Wskazówki'), findsOneWidget);
    expect(find.textContaining('Jasna wizja produktu'), findsOneWidget);
    expect(find.textContaining('Brak twardych liczb'), findsOneWidget);
    expect(find.textContaining('Przygotuj jedną liczbę'), findsOneWidget);
  });

  testWidgets('Voice: przycisk mikrofonu widoczny w input barze', (tester) async {
    await _navigateToChat(tester);
    expect(find.byIcon(Icons.mic_none), findsOneWidget);
    expect(find.text('Wyślij'), findsOneWidget);
  });

  testWidgets('Voice: STT wypełnia pole tekstowe bez automatycznego wysyłania',
      (tester) async {
    ServiceLocator.register(
      voiceService: MockVoiceService(
        transcriptOverride: 'Chcę przećwiczyć negocjację ceny.',
      ),
    );
    addTearDown(() => ServiceLocator.register(voiceService: null));

    await _navigateToChat(tester);

    await tester.tap(find.byIcon(Icons.mic_none));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Transkrypcja trafiła do pola (confirm-before-lock), NIE wysłana:
    // tekst występuje dokładnie raz — w EditableText pola, bez bąbelka.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Chcę przećwiczyć negocjację ceny.');
    expect(find.text('Chcę przećwiczyć negocjację ceny.'), findsOneWidget);
  });

  testWidgets('Voice: STT pusty wynik → komunikat, brak wysyłki', (tester) async {
    ServiceLocator.register(
      voiceService: MockVoiceService(simulateSttFailure: true),
    );
    addTearDown(() => ServiceLocator.register(voiceService: null));

    await _navigateToChat(tester);

    await tester.tap(find.byIcon(Icons.mic_none));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Nie rozpoznano mowy. Spróbuj ponownie albo wpisz tekst.'),
        findsOneWidget);
  });

  testWidgets('Voice: edycja transkrypcji przed wysłaniem (korekta STT)',
      (tester) async {
    ServiceLocator.register(
      voiceService: MockVoiceService(
        transcriptOverride: 'Popraw mnie błędny tekst',
      ),
    );
    addTearDown(() => ServiceLocator.register(voiceService: null));

    await _navigateToChat(tester);

    await tester.tap(find.byIcon(Icons.mic_none));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Użytkownik poprawia transkrypcję zanim wyśle.
    await tester.enterText(
        find.byType(TextField), 'Poprawiony tekst po korekcie.');
    await tester.tap(find.text('Wyślij'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    // Wysłana została POPRAWIONA wersja, nie surowa transkrypcja.
    expect(find.text('Poprawiony tekst po korekcie.'), findsOneWidget);
    expect(find.text('Popraw mnie błędny tekst'), findsNothing);
  });

  testWidgets('Voice: 🔊 pojawia się przy odpowiedzi persony (TTS)', (tester) async {
    await _navigateToChat(tester);

    // Intake: odpowiedź Coacha → przycisk odtwarzania widoczny przy bąbelku.
    await tester.enterText(find.byType(TextField), 'Mam gotowe MVP.');
    await tester.tap(find.text('Wyślij'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.textContaining('Coach'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
  });
}
