import 'package:flutter_test/flutter_test.dart';

import 'package:benedictum_mobile/services/onesignal_service.dart';

/// Testy kontraktu OneSignalService (Część D2).
/// Bez platformy (test environment) SDK nie jest inicjalizowany —
/// wszystkie metody muszą bezpiecznie nic nie robić (bez crasha).
void main() {
  group('OneSignalService — tryb niezainicjalizowany', () {
    test('init z pustym App ID nie inicjalizuje SDK', () async {
      final service = OneSignalService.instance;
      expect(service.isInitialized, isFalse);
      await service.init(appId: '');
      expect(service.isInitialized, isFalse);
    });

    test('setTags nie rzuca bez inicjalizacji', () async {
      final service = OneSignalService.instance;
      await service.setTags(userId: 'user-1', tier: 'free');
      // Bez błędu — to wystarczający dowód braku crasha.
    });

    test('setDeepLinkHandler nie rzuca bez inicjalizacji', () {
      final service = OneSignalService.instance;
      service.setDeepLinkHandler((url) {});
      // Bez błędu — to wystarczający dowód braku crasha.
    });
  });
}
