import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:benedictum_mobile/app.dart';

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
}
