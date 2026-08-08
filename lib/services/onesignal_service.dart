import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'interfaces/i_onesignal_service.dart';

/// Serwis powiadomień push OneSignal — Część D2.
/// App ID wyłącznie przez --dart-define (ONESIGNAL_APP_ID), zero literałów.
/// Init tylko na Android/iOS (!kIsWeb); brak App ID → brak inicjalizacji.
class OneSignalService implements IOneSignalService {
  OneSignalService._();
  static final OneSignalService instance = OneSignalService._();

  static const String _appId = String.fromEnvironment('ONESIGNAL_APP_ID');

  bool _initialized = false;
  bool _deepLinkHandlerRegistered = false;

  /// Czy SDK został zainicjalizowany.
  @override
  bool get isInitialized => _initialized;

  /// Inicjalizacja SDK. Wymaga prawdziwego [appId] (UUID z konsoli OneSignal).
  /// Pusty/invalid App ID → brak inicjalizacji (bez crasha).
  @override
  Future<void> init({String? appId}) async {
    if (_initialized) return;
    final id = appId ?? _appId;
    if (id.isEmpty) return;

    await OneSignal.initialize(id);
    _initialized = true;
  }

  /// Ustawia tagi powiadomień (np. user_id, tier subskrypcji).
  @override
  Future<void> setTags({
    required String userId,
    required String tier,
  }) async {
    if (!_initialized) return;
    await OneSignal.User.addTags({
      'user_id': userId,
      'tier': tier,
    });
  }

  /// Rejestruje handler głębokiego linku z powiadomień (deep link
  /// `benedictum://paywall`). Odblokowuje nawigację do ekranu paywall,
  /// gdy użytkownik kliknie powiadomienie z launchUrl.
  @override
  void setDeepLinkHandler(void Function(String url)? handler) {
    if (!_initialized || _deepLinkHandlerRegistered) return;
    _deepLinkHandlerRegistered = true;
    OneSignal.Notifications.addClickListener((event) {
      final url = event.notification.launchUrl;
      if (url != null && url.isNotEmpty && handler != null) {
        handler(url);
      }
    });
  }
}
