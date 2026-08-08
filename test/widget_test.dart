import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:benedictum_mobile/app.dart';

void main() {
  testWidgets('Splash renderuje appTitle po polsku', (tester) async {
    await tester.pumpWidget(BenedictumApp());
    // Przysunięcie czasu — timery fade-in i AnimatedOpacity.
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Benedictum'), findsOneWidget);
    expect(find.text('Przejdź dalej'), findsOneWidget);
  });

  testWidgets('Nawigacja Splash -> Auth -> Home', (tester) async {
    await tester.pumpWidget(BenedictumApp());
    // Przysunięcie czasu — timery fade-in i AnimatedOpacity.
    await tester.pump(const Duration(milliseconds: 800));

    // Splash widoczny.
    expect(find.text('Benedictum'), findsOneWidget);

    // Klik „Przejdź dalej" — przejście do /auth.
    await tester.tap(find.text('Przejdź dalej'));
    await tester.pumpAndSettle();

    // Auth otwarty (tytuł z ARB po polsku — AppBar + body).
    expect(find.text('Logowanie'), findsNWidgets(2));

    // Klik „Zaloguj" — przejście do /home.
    await tester.enterText(find.widgetWithText(TextField, 'E-mail'), 'a@b.com');
    await tester.enterText(find.widgetWithText(TextField, 'Hasło'), 'secret');
    await tester.tap(find.text('Zaloguj'));
    await tester.pumpAndSettle();

    // Home otwarty (tytuł + karta scenariusza).
    expect(find.text('Strona główna'), findsOneWidget);
    expect(find.text('Pitch do inwestora'), findsOneWidget);
  });
}
