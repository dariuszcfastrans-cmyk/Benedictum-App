/// Interfejs serwisu powiadomień push OneSignal (Część D2).
/// Umożliwia wstrzyknięcie mocka w testach oraz w innych usługach.
abstract interface class IOneSignalService {
  /// Czy SDK został zainicjalizowany.
  bool get isInitialized;

  /// Inicjalizacja SDK (pusty App ID → brak inicjalizacji).
  Future<void> init({String? appId});

  /// Ustawia tagi powiadomień (user_id, tier).
  Future<void> setTags({
    required String userId,
    required String tier,
  });

  /// Rejestruje handler głębokiego linku z powiadomień.
  void setDeepLinkHandler(void Function(String url)? handler);
}
