import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:benedictum_mobile/l10n/app_localizations.dart';

import 'config/locale_controller.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'services/onesignal_service.dart';

/// Główny widget aplikacji Benedictum.
/// Zmiana locale w Settings przełącza UI bez restartu procesu.
class BenedictumApp extends StatefulWidget {
  const BenedictumApp({super.key});

  @override
  State<BenedictumApp> createState() => _BenedictumAppState();
}

class _BenedictumAppState extends State<BenedictumApp> {
  // Router tworzony raz — nie w build, by zmiana locale nie resetowała nawigacji.
  late final GoRouter _router = createRouter();

  @override
  void initState() {
    super.initState();
    // Deep link z powiadomień OneSignal: benedictum://paywall → ekran płatności.
    OneSignalService.instance.setDeepLinkHandler((url) {
      if (url.startsWith('benedictum://paywall')) {
        _router.go(AppRoutes.paywall);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleController.instance.locale,
      builder: (context, locale, _) {
        return MaterialApp.router(
          title: 'Benedictum',
          theme: AppTheme.dark,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('pl'),
            Locale('en'),
            Locale('fr'),
            Locale('es'),
          ],
          locale: locale,
          routerConfig: _router,
        );
      },
    );
  }
}
