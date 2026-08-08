import 'package:purchases_flutter/purchases_flutter.dart';

/// Serwis subskrypcji RevenueCat — Część C2.
/// Klucz publiczny wyłącznie przez --dart-define (REVENUECAT_KEY), zero literałów.
/// Init tylko na Android/iOS (!kIsWeb); brak klucza → brak inicjalizacji (bez crasha).
class RevenueCatService {
  RevenueCatService._();
  static final RevenueCatService instance = RevenueCatService._();

  static const String _proEntitlementId = 'pro_access';
  static const String _apiKey = String.fromEnvironment('REVENUECAT_KEY');

  bool _initialized = false;

  /// Czy SDK został zainicjalizowany.
  bool get isInitialized => _initialized;

  /// Konfiguracja SDK. Wymaga prawdziwego [apiKey] przekazanego z zewnątrz
  /// (--dart-define). appUserID wiąże subskrypcję z zalogowanym użytkownikiem.
  /// Błędy SDK (np. brak platformy w środowisku testowym/web) nie blokują startu.
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

  /// Czy bieżący użytkownik ma aktywny entitlement 'pro_access'.
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
