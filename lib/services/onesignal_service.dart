import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Serwis powiadomień push OneSignal — Część C1.
/// UWAGA: klasa zdefiniowana, ale [init] NIE jest wywoływane w C1.
/// OneSignal.initialize() z pustym/invalid App ID kończy się FATAL —
/// wymaga prawdziwego App ID (UUID) od Operatora (STOP w C1).
class OneSignalService {
  OneSignalService._();
  static final OneSignalService instance = OneSignalService._();

  /// Inicjalizacja SDK. Wymaga prawdziwego [appId] (UUID z konsoli OneSignal).
  /// Wywołanie nastąpi w C2 po dostarczeniu identyfikatora.
  Future<void> init({required String appId}) async {
    await OneSignal.initialize(appId);
  }

  /// Ustawia tagi powiadomień (np. wersja aplikacji, język).
  Future<void> setTags(Map<String, dynamic> tags) async {
    await OneSignal.User.addTags(tags);
  }
}
