import 'package:purchases_flutter/purchases_flutter.dart';

/// Interfejs serwisu subskrypcji RevenueCat (Część D2).
/// Umożliwia wstrzyknięcie mocka w testach oraz w innych usługach.
abstract interface class IRevenueCatService {
  /// Czy SDK został zainicjalizowany.
  bool get isInitialized;

  /// Konfiguracja SDK (klucz publiczny, opcjonalny appUserID).
  Future<void> init({String? apiKey, String? userId});

  /// Wiąże bieżącego użytkownika z subskrypcją (appUserID).
  Future<void> setUserId(String userId);

  /// Pobiera konfigurację ofert (offering default + pakiety).
  Future<Offerings?> getOfferings();

  /// Wykonuje zakup pakietu. Zwraca CustomerInfo lub null.
  Future<CustomerInfo?> purchasePackage(Package package);

  /// Przywraca wcześniejsze zakupy. Zwraca CustomerInfo lub null.
  Future<CustomerInfo?> restorePurchases();

  /// Czy bieżący użytkownik ma aktywny entitlement 'Benedictum Pro'.
  Future<bool> checkProAccess();

  /// Data wygaśnięcia entitlementu Pro (null przy lifetime/braku).
  Future<DateTime?> getProExpiryDate();
}
