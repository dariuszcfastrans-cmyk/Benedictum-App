import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:benedictum_mobile/app.dart';

Future<void> _navigateToAuth(WidgetTester tester) async {
  await tester.pumpWidget(BenedictumApp());
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pumpAndSettle();

  // Splash → Auth.
  await tester.tap(find.text('Przejdź dalej'));
  await tester.pumpAndSettle();
}

Future<void> _login(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextField, 'E-mail'), 'a@b.com');
  await tester.enterText(find.widgetWithText(TextField, 'Hasło'), 'secret');
  await tester.tap(find.text('Zaloguj'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Auth flow: logowanie → Home', (tester) async {
    await _navigateToAuth(tester);

    // Auth otwarty: tytuł + pola.
    expect(find.text('Logowanie'), findsNWidgets(2));
    expect(find.widgetWithText(TextField, 'E-mail'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Hasło'), findsOneWidget);

    await _login(tester);

    // Home otwarty.
    expect(find.text('Strona główna'), findsOneWidget);
    expect(find.text('Pitch do inwestora'), findsOneWidget);
  });

  testWidgets('Auth flow: rejestracja → komunikat o potwierdzeniu e-maila → Home',
      (tester) async {
    await _navigateToAuth(tester);

    // Przełącz na rejestrację.
    await tester.tap(find.text('Nie masz konta? Zarejestruj się'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'E-mail'), 'a@b.com');
    await tester.enterText(find.widgetWithText(TextField, 'Hasło'), 'secret');
    await tester.tap(find.text('Zarejestruj się'));
    await tester.pumpAndSettle();

    // Snackbar o potwierdzeniu e-maila + Home.
    expect(
      find.text('Konto utworzone. Potwierdź e-mail, aby dokończyć.'),
      findsOneWidget,
    );
    expect(find.text('Strona główna'), findsOneWidget);
  });

  testWidgets('Auth flow: puste pola → komunikat o błędzie', (tester) async {
    await _navigateToAuth(tester);

    await tester.tap(find.text('Zaloguj'));
    await tester.pumpAndSettle();

    expect(find.text('Email i hasło są wymagane.'), findsOneWidget);
    // Dalej na Auth.
    expect(find.text('Logowanie'), findsNWidgets(2));
  });
}
