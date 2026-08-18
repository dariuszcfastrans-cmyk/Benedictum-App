import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:benedictum_mobile/app.dart';
import 'package:benedictum_mobile/config/locale_controller.dart';

Future<void> _navigateToSettings(WidgetTester tester) async {
  await tester.pumpWidget(BenedictumApp());
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

  // Home → Settings (ikona koła zębatego).
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // LocaleController to singleton — reset do PL między testami.
    LocaleController.instance.locale.value = const Locale('pl');
  });

  testWidgets('Settings: zmiana języka przełącza UI bez restartu procesu', (tester) async {
    await _navigateToSettings(tester);

    // Domyślnie UI po polsku.
    expect(find.text('Ustawienia'), findsOneWidget);

    // Wybierz język angielski w dropdownie.
    await tester.tap(find.byType(DropdownButtonFormField<Locale>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    // UI przełączone na angielski — bez restartu procesu.
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets('Settings: usunięcie konta wymaga potwierdzenia i wraca do splash', (tester) async {
    await _navigateToSettings(tester);

    // Przycisk usuwania konta widoczny.
    expect(find.text('Usuń konto'), findsOneWidget);

    // Klik — pojawia się dialog potwierdzenia.
    await tester.tap(find.text('Usuń konto'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('trwale usunięte'),
      findsOneWidget,
    );

    // Anuluj — zostajemy na ustawieniach.
    await tester.tap(find.text('Anuluj'));
    await tester.pumpAndSettle();
    expect(find.text('Ustawienia'), findsOneWidget);

    // Potwierdź — wracamy do splash (mock deleteAccount czyści sesję).
    await tester.tap(find.text('Usuń konto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usuń').last);
    await tester.pumpAndSettle();
    expect(find.text('Przejdź dalej'), findsOneWidget);
  });
}
