import 'package:flutter/material.dart';
import 'package:benedictum_mobile/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:benedictum_mobile/app.dart';

void main() {
  testWidgets('Splash renderuje appTitle po polsku', (tester) async {
    await tester.pumpWidget(const BenedictumApp());

    // Lokalizacja domyślna: pl.
    expect(AppLocalizations.of(tester.element(find.byType(Text).first)).localeName, 'pl');
    expect(find.text('Benedictum'), findsOneWidget);
    expect(find.text('Przejdź dalej'), findsOneWidget);
  });

  testWidgets('Nawigacja Splash -> Home zamyka Splash i otwiera Home', (tester) async {
    await tester.pumpWidget(const BenedictumApp());

    // Splash widoczny.
    expect(find.text('Benedictum'), findsOneWidget);

    // Klik „Przejdź dalej" — przejście do /home.
    await tester.tap(find.text('Przejdź dalej'));
    await tester.pumpAndSettle();

    // Splash zamknięty, Home otwarty (tytuł z ARB po polsku).
    expect(find.text('Strona główna'), findsOneWidget);
    expect(find.text('Benedictum'), findsNothing);
  });
}
