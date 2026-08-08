import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:benedictum_mobile/services/revenuecat_service.dart';

/// Testy kontraktu RevenueCatService (Część D2).
/// Bez platformy (test environment) SDK nie jest inicjalizowany —
/// wszystkie metody muszą bezpiecznie zwracać wartości domyślne (bez crasha).
void main() {
  group('RevenueCatService — tryb niezainicjalizowany', () {
    test('init z pustym kluczem nie inicjalizuje SDK', () async {
      final service = RevenueCatService.instance;
      expect(service.isInitialized, isFalse);
      await service.init(apiKey: '');
      expect(service.isInitialized, isFalse);
    });

    test('checkProAccess zwraca false bez inicjalizacji', () async {
      final service = RevenueCatService.instance;
      expect(await service.checkProAccess(), isFalse);
    });

    test('getOfferings zwraca null bez inicjalizacji', () async {
      final service = RevenueCatService.instance;
      expect(await service.getOfferings(), isNull);
    });

    test('purchasePackage zwraca null bez inicjalizacji', () async {
      final service = RevenueCatService.instance;
      expect(await service.purchasePackage(_fakePackage()), isNull);
    });

    test('restorePurchases zwraca null bez inicjalizacji', () async {
      final service = RevenueCatService.instance;
      expect(await service.restorePurchases(), isNull);
    });

    test('getProExpiryDate zwraca null bez inicjalizacji', () async {
      final service = RevenueCatService.instance;
      expect(await service.getProExpiryDate(), isNull);
    });

    test('setUserId nie rzuca bez inicjalizacji', () async {
      final service = RevenueCatService.instance;
      await service.setUserId('user-1');
      // Bez błędu — to wystarczający dowód braku crasha.
    });
  });
}

/// Tworzy minimalny Package. Nie wywołujemy SDK — tylko przekazujemy obiekt
/// do metody, która i tak kończy się na guardzie !isInitialized.
Package _fakePackage() {
  final product = StoreProduct(
    'monthly_pro',
    'Benedictum Pro — monthly',
    'Benedictum Pro',
    9.99,
    '\$9.99',
    'USD',
    subscriptionPeriod: 'P1M',
  );
  final context = PresentedOfferingContext('default', null, null);
  return Package('monthly_pro', PackageType.monthly, product, context);
}
