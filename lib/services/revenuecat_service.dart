import 'package:purchases_flutter/purchases_flutter.dart';

/// Serwis subskrypcji RevenueCat — Część C1.
/// Inicjalizacja z placeholderem (pusty klucz jest tolerowany przez SDK).
/// Prawdziwy klucz publiczny w C2 (konfiguracja backendu, nie kod).
class RevenueCatService {
  RevenueCatService._();
  static final RevenueCatService instance = RevenueCatService._();

  static const String _proEntitlementId = 'pro_access';

  bool _initialized = false;

  /// Konfiguracja SDK. [apiKey] — placeholder w C1 ('').
  /// Ustawia tryb logowania na błędy i rejestruje identyfikator entitlementu.
  /// Błędy SDK (np. brak platformy w środowisku testowym/web) nie blokują startu.
  Future<void> init({required String apiKey}) async {
    if (_initialized) return;
    try {
      await Purchases.setLogLevel(LogLevel.error);
      await Purchases.configure(PurchasesConfiguration(apiKey));
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  /// Czy bieżący użytkownik ma aktywny entitlement 'pro_access'.
  /// W C1 zwraca mockowo false (brak płatności); w C2 — prawdziwe dane SDK.
  Future<bool> hasProAccess() async {
    if (!_initialized) return false;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey(_proEntitlementId);
    } catch (_) {
      return false;
    }
  }
}
