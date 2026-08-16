import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:benedictum_mobile/config/routes.dart';
import 'package:benedictum_mobile/features/history/history_screen.dart';
import 'package:benedictum_mobile/features/report/report_screen.dart';
import 'package:benedictum_mobile/l10n/app_localizations.dart';
import 'package:benedictum_mobile/models/report.dart';
import 'package:benedictum_mobile/services/mocks/mock_api_service.dart';

/// Minimalny harness nawigacji (GoRouter) dla testów HistoryScreen.
Widget _harness(MockApiService apiService) {
  final router = GoRouter(
    initialLocation: AppRoutes.history,
    routes: [
      GoRoute(
        path: AppRoutes.history,
        builder: (context, state) => HistoryScreen(apiService: apiService),
      ),
      GoRoute(
        path: AppRoutes.report,
        builder: (context, state) => const ReportScreen(),
      ),
    ],
  );
  return MaterialApp.router(
    title: 'Benedictum Test',
    routerConfig: router,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [
      Locale('pl'),
      Locale('en'),
      Locale('fr'),
      Locale('es'),
    ],
    locale: const Locale('pl'),
  );
}

void main() {
  testWidgets('Historia: pusty stan pokazuje komunikat braku sesji',
      (tester) async {
    final api = MockApiService();
    await tester.pumpWidget(_harness(api));
    await tester.pumpAndSettle();

    expect(find.text('Historia'), findsOneWidget);
    expect(find.textContaining('Brak zapisanych sesji'), findsOneWidget);
  });

  testWidgets('Historia: lista sesji, otwarcie raportu i usunięcie z potwierdzeniem',
      (tester) async {
    final api = MockApiService();
    await tester.runAsync(() => api.saveSession(
          scenarioKey: 'pitch',
          title: 'Pitch do inwestora',
          userStatements: const ['Mam gotowe MVP.'],
          report: const Report(
            strengths: ['Mocna analiza (zapisana)'],
            gaps: ['Ryzyko kosztów'],
            actionItems: ['Weryfikacja liczb'],
            overallRating: 4,
          ),
        ));

    await tester.pumpWidget(_harness(api));
    await tester.pumpAndSettle();

    // Lista zawiera zapisaną sesję.
    expect(find.text('Pitch do inwestora'), findsOneWidget);
    expect(find.textContaining('Brak zapisanych sesji'), findsNothing);

    // Otwarcie sesji → ReportScreen z zapisanym raportem.
    await tester.tap(find.text('Pitch do inwestora'));
    await tester.pumpAndSettle();
    expect(find.text('Raport'), findsOneWidget);
    expect(find.text('4/5'), findsOneWidget);
    expect(find.text('Zobacz historię'), findsOneWidget);

    // Powrót do historii.
    await tester.tap(find.text('Zobacz historię'));
    await tester.pumpAndSettle();
    expect(find.text('Historia'), findsOneWidget);

    // Usunięcie: najpierw potwierdzenie.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Usuń sesję'), findsOneWidget);

    // Anuluj — sesja pozostaje.
    await tester.tap(find.text('Anuluj'));
    await tester.pumpAndSettle();
    expect(find.text('Pitch do inwestora'), findsOneWidget);

    // Usuń z potwierdzeniem — sesja znika z listy.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usuń'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Brak zapisanych sesji'), findsOneWidget);
  });

  testWidgets('Historia: sesja usunięta w tle → komunikat niedostępności',
      (tester) async {
    final api = MockApiService();
    await tester.runAsync(() async {
      await api.saveSession(
        scenarioKey: 'pitch',
        title: 'Pitch do inwestora',
        userStatements: const ['Mam gotowe MVP.'],
        report: const Report(
          strengths: ['Mocna analiza (zapisana)'],
          gaps: ['Ryzyko kosztów'],
          actionItems: ['Weryfikacja liczb'],
          overallRating: 4,
        ),
      );
    });
    String? id;
    await tester.runAsync(() async {
      id = (await api.getSessionHistory()).single.id;
    });

    await tester.pumpWidget(_harness(api));
    await tester.pumpAndSettle();

    // Sesja znika w „serwerze" zanim użytkownik ją otworzy.
    await tester.runAsync(() => api.deleteSession(id!));
    await tester.tap(find.text('Pitch do inwestora'));
    await tester.pumpAndSettle();

    // Brak pustego ekranu/crasha — komunikat i powrót do listy.
    expect(find.text('Historia'), findsOneWidget);
    expect(find.textContaining('niedostępna'), findsOneWidget);
  });
}
