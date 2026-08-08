import 'package:purchases_flutter/purchases_flutter.dart';

import 'interfaces/i_revenuecat_service.dart';

/// Serwis subskrypcji RevenueCat — Część D2.
/// Klucz publiczny wyłącznie przez --dart-define (REVENUECAT_KEY), zero literałów.
/// Init tylko na Android/iOS (!kIsWeb); brak klucza → brak inicjalizacji (bez crasha).
class RevenueCatService implements IRevenueCatService {
  RevenueCatService._();
  static final RevenueCatService instance = RevenueCatService._();

  /// Entitlement 'Benedictum Pro' — zgodnie z dashboardem RevenueCat
  /// (Project Benedictum, proj78fd05bc).
  static const String proEntitlementId = 'Benedictum Pro';
  static const String _apiKey = String.fromEnvironment('REVENUECAT_KEY');

  bool _initialized = false;

  /// Czy SDK został zainicjalizowany.
  @override
  bool get isInitialized => _initialized;

  /// Konfiguracja SDK. Wymaga prawdziwego [apiKey] przekazanego z zewnątrz
  /// (--dart-define). appUserID wiąże subskrypcję z zalogowanym użytkownikiem.
  /// Błędy SDK (np. brak platformy w środowisku testowym/web) nie blokują startu.
  @override
  Future<void> init({String? apiKey, String? userId}) async {
    if (_initialized) return;
    final key = apiKey ?? _apiKey;
    if (key.isEmpty) return; // brak klucza — nie inicjalizuj (brak crasha)

    try {
      await Purchases.setLogLevel(LogLevel.error);
      final configuration = PurchasesConfiguration(key);
      if (userId != null && userId.isNotEmpty) {
        configuration.appUserID = userId;
      }
      await Purchases.configure(configuration);
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  /// Wiąże bieżącego użytkownika z subskrypcją (RevenueCat appUserID).
  @override
  Future<void> setUserId(String userId) async {
    if (!_initialized || userId.isEmpty) return;
    try {
      await Purchases.logIn(userId);
    } catch (_) {
      // Nie blokuj logowania, gdy bind zawiedzie (np. brak sieci).
    }
  }

  /// Pobiera konfigurację ofert (offering default + 3 pakiety).
  @override
  Future<Offerings?> getOfferings() async {
    if (!_initialized) return null;
    try {
      return await Purchases.getOfferings();
    } catch (_) {
      return null;
    }
  }

  /// Wykonuje zakup pakietu. Zwraca CustomerInfo lub null przy błędzie/anulowaniu.
  @override
  Future<CustomerInfo?> purchasePackage(Package package) async {
    if (!_initialized) return null;
    try {
      // ignore: deprecated_member_use — dyrektywa D2 wymaga purchasePackage.
      final result = await Purchases.purchasePackage(package);
      return result.customerInfo;
    } catch (_) {
      return null;
    }
  }

  /// Przywraca wcześniejsze zakupy. Zwraca CustomerInfo lub null przy błędzie.
  @override
  Future<CustomerInfo?> restorePurchases() async {
    if (!_initialized) return null;
    try {
      return await Purchases.restorePurchases();
    } catch (_) {
      return null;
    }
  }

  /// Czy bieżący użytkownik ma aktywny entitlement 'Benedictum Pro'.
  @override
  Future<bool> checkProAccess() async {
    if (!_initialized) return false;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey(proEntitlementId);
    } catch (_) {
      return false;
    }
  }

  /// Data wygaśnięcia entitlementu Pro (null przy lifetime/braku).
  @override
  Future<DateTime?> getProExpiryDate() async {
    if (!_initialized) return null;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlement = customerInfo.entitlements.active[proEntitlementId];
      final raw = entitlement?.expirationDate;
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }
}
