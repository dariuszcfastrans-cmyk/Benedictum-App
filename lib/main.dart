import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/locale_controller.dart';
import 'services/onesignal_service.dart';
import 'services/revenuecat_service.dart';
import 'services/service_locator.dart';
import 'services/supabase_api_service.dart';
import 'services/supabase_auth_service.dart';
import 'services/voice_service.dart';

// Klucze publiczne wyłącznie z --dart-define. Zero literałów w kodzie.
const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const String oneSignalAppId = String.fromEnvironment('ONESIGNAL_APP_ID');
const String revenueCatKey = String.fromEnvironment('REVENUECAT_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Wczytaj zapisane języki (UI + rozmowa). Brak zapisu → wartości domyślne.
  await LocaleController.instance.load();

  // C2: Supabase online, jeśli zmienne obecne; inaczej offline (Mock — C1 behavior).
  final bool online = supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  if (online) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
    ServiceLocator.register(
      authService: SupabaseAuthService(),
      apiService: SupabaseApiService(),
      voiceService: VoiceService(),
    );
  } else {
    // Fallback offline: UI sam korzysta z Mock* (C1 behavior).
    ServiceLocator.register(authService: null, apiService: null);
  }

  // R2: język rozmowy (STT+TTS) — niezależna decyzja użytkownika, ustawiony
  // na VoiceService przy starcie (zapisany wybór lub domyślny EN).
  final voice = ServiceLocator.voiceService;
  if (voice != null) {
    voice.setConversationLanguage(
      LocaleController.instance.conversationLanguage.value,
    );
  }

  // SDK natywne wyłącznie na Android/iOS (!kIsWeb).
  // RevenueCat/OneSignal bez klucza → brak inicjalizacji (bez crasha).
  if (!kIsWeb) {
    if (oneSignalAppId.isNotEmpty) {
      await OneSignalService.instance.init(appId: oneSignalAppId);
    }
    if (revenueCatKey.isNotEmpty) {
      await RevenueCatService.instance.init(apiKey: revenueCatKey);
    }
  }

  runApp(BenedictumApp());
}
