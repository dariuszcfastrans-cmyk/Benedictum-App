import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:benedictum_mobile/app.dart';
import 'package:benedictum_mobile/config/routes.dart';

/// E2E Fala 1B — pełny flow na fizycznym urządzeniu (S23 Ultra).
/// Osobny plik — nie modyfikuje istniejącego app_test.dart.
///
/// Build offline (brak SUPABASE keys → MockAuthService/MockApiService):
/// weryfikacja logiki Fali 1B niezależna od backendu.
///
/// Flow: Splash → Auth (mock login) → Home → Chat (pitch_investor)
///       → Intake (1 odpowiedź Coacha) → decyzja użytkownika („Przejdź do
///       analizy") → Analyze (3 persony) → Paywall osiągalny.
///
/// Uwaga o bramie Pro: bez REVENUECAT_KEY brama jest pomijana (dev/offline),
/// więc Intake i Analyze działają. Paywall weryfikujemy nawigacją /paywall
/// (dowód: ekran osiągalny i poprawnie obsługuje brak ofert).
///
/// Technika na fizycznym urządzeniu: tekst ustawiamy bezpośrednio w
/// controllery (enterText otwiera klawiaturę systemową, która przechwytuje
/// późniejsze tapy); czasy oczekiwania pokrywają realny rendering + mock API.
Future<void> _navigateToChat(WidgetTester tester) async {
  await tester.pumpWidget(BenedictumApp());
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 100));

  // Splash → Auth.
  await tester.tap(find.text('Przejdź dalej'));
  await tester.pump(const Duration(milliseconds: 400));

  // Auth → Home (mock login: dowolne dane).
  final emailField =
      tester.widget<TextField>(find.widgetWithText(TextField, 'E-mail'));
  emailField.controller!.text = 'e2e@benedictum.dev';
  final passField =
      tester.widget<TextField>(find.widgetWithText(TextField, 'Hasło'));
  passField.controller!.text = 'e2e-secret';
  await tester.pump(const Duration(milliseconds: 200));

  await tester.ensureVisible(find.text('Zaloguj'));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(find.text('Zaloguj'));
  await tester.pump(const Duration(milliseconds: 1800));
  await tester.pump(const Duration(milliseconds: 1200));

  // Home → Chat (scenariusz pitch_investor).
  await tester.tap(find.text('Pitch do inwestora'));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E 1B: Login → Chat → Intake (1 Coach) → decyzja → Analyze (3 persony)',
      (tester) async {
    await _navigateToChat(tester);

    // Sprawdzona metoda: tekst bezpośrednio w controller, bez enterText.
    Future<void> setChatInput(String text) async {
      final field =
          tester.widget<TextField>(find.byType(TextField));
      field.controller!.text = text;
      await tester.pump(const Duration(milliseconds: 150));
    }

    // --- Intake: pierwsza wiadomość → wyłącznie Coach (Fala 1B) ---
    await setChatInput('Mam gotowe MVP.');
    await tester.ensureVisible(find.text('Wyślij'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Wyślij'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 1600));

    // Wiadomość użytkownika widoczna.
    expect(find.text('Mam gotowe MVP.'), findsOneWidget);

    // W intake odpowiada tylko Coach — Krytyk/Optymista NIE występują.
    expect(find.textContaining('Coach'), findsWidgets);
    expect(find.textContaining('Krytyk'), findsNothing);
    expect(find.textContaining('Optymista'), findsNothing);

    // Po zebraniu wypowiedzi pojawia się przycisk decyzji użytkownika.
    expect(find.text('Przejdź do analizy'), findsOneWidget);

    // --- Decyzja użytkownika: przejście do analyze ---
    await tester.tap(find.text('Przejdź do analizy'));
    await tester.pump(const Duration(milliseconds: 400));

    // --- Analyze: kolejna wiadomość → 3 odpowiedzi person ---
    await setChatInput('Proszę o pełną analizę.');
    await tester.ensureVisible(find.text('Wyślij'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Wyślij'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 2500));

    // Wszystkie 3 persony odpowiedziały.
    expect(find.textContaining('Krytyk'), findsWidgets);
    expect(find.textContaining('Optymista'), findsWidgets);
    expect(find.textContaining('Coach'), findsWidgets);

    // Przycisk decyzji znika po przejściu do analyze.
    expect(find.text('Przejdź do analizy'), findsNothing);
  });

  testWidgets('E2E 1B: Paywall osiągalny przez /paywall (brak ofert w offline)',
      (tester) async {
    await _navigateToChat(tester);

    // Nawigacja do paywall (ścieżka deep linku benedictum://paywall).
    final context = tester.element(find.byType(TextField));
    GoRouter.of(context).go(AppRoutes.paywall);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 1200));

    // Ekran paywall widoczny: tytuł + obsługa braku ofert (offline, bez klucza).
    expect(find.text('Benedictum Pro'), findsWidgets);
    expect(find.text('Nie udało się pobrać ofert. Spróbuj ponownie.'), findsOneWidget);
    expect(find.text('Spróbuj ponownie'), findsOneWidget);
  });
}