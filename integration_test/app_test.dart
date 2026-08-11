import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:benedictum_mobile/app.dart';

/// Test integracyjny uruchamiany na prawdziwym urządzeniu/przeglądarce.
/// Zamyka lukę dowodową Części B: potwierdza start aplikacji i Splash po polsku.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Aplikacja startuje, Splash → Auth', (tester) async {
    await tester.pumpWidget(BenedictumApp());
    // Przysunięcie czasu — timery fade-in i AnimatedOpacity Splash.
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    // Splash: logo + przycisk dalej.
    expect(find.text('Benedictum'), findsOneWidget);
    expect(find.text('Przejdź dalej'), findsOneWidget);

    // Splash → Auth: ekran logowania z polami E-mail i Hasło.
    await tester.tap(find.text('Przejdź dalej'));
    await tester.pumpAndSettle();
    expect(find.text('Logowanie'), findsWidgets);
    expect(find.widgetWithText(TextField, 'E-mail'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Hasło'), findsOneWidget);
    expect(find.text('Zaloguj'), findsOneWidget);
  });

  testWidgets('Auth: walidacja i przełączanie trybu logowania/rejestracji',
      (tester) async {
    await tester.pumpWidget(BenedictumApp());
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Przejdź dalej'));
    await tester.pumpAndSettle();

    // Puste pola → komunikat walidacji, brak nawigacji.
    await tester.tap(find.text('Zaloguj'));
    await tester.pumpAndSettle();
    expect(find.text('Email i hasło są wymagane.'), findsOneWidget);

    // Przełączenie do trybu rejestracji.
    await tester.tap(find.text('Nie masz konta? Zarejestruj się'));
    await tester.pumpAndSettle();
    expect(find.text('Zarejestruj się'), findsOneWidget);

    // Wpisanie danych → przełączenie z powrotem do logowania.
    await tester.enterText(
        find.widgetWithText(TextField, 'E-mail'), 'test@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Hasło'), 'secret');
    await tester.tap(find.text('Masz już konto? Zaloguj się'));
    await tester.pumpAndSettle();
    expect(find.text('Zaloguj'), findsOneWidget);
  });
}
