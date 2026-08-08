import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:benedictum_mobile/app.dart';

/// Test integracyjny uruchamiany na prawdziwym urządzeniu/przeglądarce.
/// Zamyka lukę dowodową Części B: potwierdza start aplikacji i Splash po polsku.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Aplikacja startuje, Splash wyświetla się po polsku', (tester) async {
    await tester.pumpWidget(BenedictumApp());
    // Przysunięcie czasu — timery fade-in i AnimatedOpacity Splash.
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('Benedictum'), findsOneWidget);
    expect(find.text('Przejdź dalej'), findsOneWidget);

    // Pełna ścieżka: Splash → Auth → Home.
    await tester.tap(find.text('Przejdź dalej'));
    await tester.pumpAndSettle();
    expect(find.text('Logowanie'), findsNWidgets(2));

    await tester.tap(find.text('Przejdź dalej'));
    await tester.pumpAndSettle();
    expect(find.text('Strona główna'), findsOneWidget);
  });
}
