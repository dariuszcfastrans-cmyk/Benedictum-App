import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Serwis powiadomień push OneSignal — Część C2.
/// App ID wyłącznie przez --dart-define (ONESIGNAL_APP_ID), zero literałów.
/// Init tylko na Android/iOS (!kIsWeb); brak App ID → brak inicjalizacji.
class OneSignalService {
  OneSignalService._();
  static final OneSignalService instance = OneSignalService._();

  static const String _appId = String.fromEnvironment('ONESIGNAL_APP_ID');

  bool _initialized = false;

  /// Czy SDK został zainicjalizowany.
  bool get isInitialized => _initialized;

  /// Inicjalizacja SDK. Wymaga prawdziwego [appId] (UUID z konsoli OneSignal).
  /// Pusty/invalid App ID → brak inicjalizacji (bez crasha).
  Future<void> init({String? appId}) async {
    if (_initialized) return;
    final id = appId ?? _appId;
    if (id.isEmpty) return;

    await OneSignal.initialize(id);
    _initialized = true;
  }

  /// Ustawia tagi powiadomień (np. user_id, tier subskrypcji).
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
}
