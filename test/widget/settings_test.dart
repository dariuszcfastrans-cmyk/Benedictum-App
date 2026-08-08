import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:benedictum_mobile/app.dart';

Future<void> _navigateToSettings(WidgetTester tester) async {
  await tester.pumpWidget(BenedictumApp());
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pumpAndSettle();

  // Splash → Auth.
  await tester.tap(find.text('Przejdź dalej'));
  await tester.pumpAndSettle();

  // Auth → Home.
  await tester.tap(find.text('Przejdź dalej'));
  await tester.pumpAndSettle();

  // Home → Settings (ikona koła zębatego).
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();
}

void main() {
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
}
