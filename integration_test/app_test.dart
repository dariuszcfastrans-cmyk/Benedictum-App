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
}
