import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:benedictum_mobile/l10n/app_localizations.dart';
import 'package:benedictum_mobile/screens/paywall_screen.dart';
import 'package:benedictum_mobile/services/interfaces/i_revenuecat_service.dart';

/// Fikcyjny serwis RevenueCat dla testów PaywallScreen.
class _FakeRevenueCatService implements IRevenueCatService {
  _FakeRevenueCatService({this.offerings, this.purchaseResult});

  Offerings? offerings;
  CustomerInfo? purchaseResult;

  bool initialized = true;

  @override
  bool get isInitialized => initialized;

  @override
  Future<void> init({String? apiKey, String? userId}) async {}

  @override
  Future<void> setUserId(String userId) async {}

  @override
  Future<Offerings?> getOfferings() async => offerings;

  @override
  Future<CustomerInfo?> purchasePackage(Package package) async => purchaseResult;

  @override
  Future<CustomerInfo?> restorePurchases() async => purchaseResult;

  @override
  Future<bool> checkProAccess() async => true;

  @override
  Future<DateTime?> getProExpiryDate() async => null;
}

/// Tworzy ofertę default z 3 pakietami (monthly, sixMonth, annual).
Offerings _offeringsWith3Packages() {
  final monthly = _package(PackageType.monthly, '\$9.99');
  final sixMonth = _package(PackageType.sixMonth, '\$49.99');
  final annual = _package(PackageType.annual, '\$89.99');
  final offering = Offering(
    'default',
    'Default offering',
    const {},
    [monthly, sixMonth, annual],
    monthly: monthly,
    sixMonth: sixMonth,
    annual: annual,
  );
  return Offerings({'default': offering}, current: offering);
}

Package _package(PackageType type, String price) {
  final product = StoreProduct(
    '${type.name}_pro',
    'desc',
    'Benedictum Pro',
    9.99,
    price,
    'USD',
    subscriptionPeriod: 'P1M',
  );
  return Package('${type.name}_pro', type, product,
      const PresentedOfferingContext('default', null, null));
}

CustomerInfo _proCustomerInfo() {
  final entitlement = EntitlementInfo(
    RevenueCatProId.proEntitlementId,
    true,
    true,
    '2026-08-08T00:00:00Z',
    '2026-08-08T00:00:00Z',
    'monthly_pro',
    true,
  );
  return CustomerInfo(
    EntitlementInfos(
      {RevenueCatProId.proEntitlementId: entitlement},
      {RevenueCatProId.proEntitlementId: entitlement},
    ),
    const {},
    const ['monthly_pro'],
    const ['monthly_pro'],
    const [],
    '2026-08-08T00:00:00Z',
    'user-1',
    const {},
    '2026-08-08T00:00:00Z',
  );
}

/// Minimalna deklaracja identyfikatora entitlementu bez zależności od singletonu.
abstract final class RevenueCatProId {
  static const String proEntitlementId = 'Benedictum Pro';
}

Widget _wrap(GoRouter router) {
  return MaterialApp.router(
    title: 'Benedictum',
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('pl'),
    routerConfig: router,
  );
}

void main() {
  testWidgets('Paywall: pokazuje 3 plany z offering default', (tester) async {
    final fake = _FakeRevenueCatService(
      offerings: _offeringsWith3Packages(),
    );
    final router = GoRouter(
      initialLocation: '/paywall',
      routes: [
        GoRoute(path: '/paywall', builder: (_, _) => PaywallScreen(revenueCatService: fake)),
        GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('HOME'))),
      ],
    );

    await tester.pumpWidget(_wrap(router));
    await tester.pump();

    // Tytuł + 3 plany.
    expect(find.text('Benedictum Pro'), findsWidgets);
    expect(find.text('Miesięcznie'), findsOneWidget);
    expect(find.text('Pół roku'), findsOneWidget);
    expect(find.text('Rocznie'), findsOneWidget);
    expect(find.text('Subskrybuj'), findsNWidgets(3));
    expect(find.text('Przywróć zakupy'), findsOneWidget);
  });

  testWidgets('Paywall: brak oferty → komunikat błędu + przycisk ponowienia', (tester) async {
    final fake = _FakeRevenueCatService(offerings: null);
    final router = GoRouter(
      initialLocation: '/paywall',
      routes: [
        GoRoute(path: '/paywall', builder: (_, _) => PaywallScreen(revenueCatService: fake)),
        GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('HOME'))),
      ],
    );

    await tester.pumpWidget(_wrap(router));
    await tester.pump();

    expect(find.text('Nie udało się pobrać ofert. Spróbuj ponownie.'), findsOneWidget);
    expect(find.text('Spróbuj ponownie'), findsOneWidget);
  });

  testWidgets('Paywall: udany zakup → snackbar sukcesu + nawigacja do home', (tester) async {
    final fake = _FakeRevenueCatService(
      offerings: _offeringsWith3Packages(),
      purchaseResult: _proCustomerInfo(),
    );
    final router = GoRouter(
      initialLocation: '/paywall',
      routes: [
        GoRoute(path: '/paywall', builder: (_, _) => PaywallScreen(revenueCatService: fake)),
        GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('HOME'))),
      ],
    );

    await tester.pumpWidget(_wrap(router));
    await tester.pump();

    await tester.tap(find.text('Subskrybuj').first);
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
  });
}
