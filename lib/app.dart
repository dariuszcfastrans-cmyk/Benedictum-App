import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:benedictum_mobile/l10n/app_localizations.dart';

import 'config/locale_controller.dart';
import 'config/routes.dart';
import 'config/theme.dart';

/// Główny widget aplikacji Benedictum.
/// Zmiana locale w Settings przełącza UI bez restartu procesu.
class BenedictumApp extends StatelessWidget {
  BenedictumApp({super.key});

  // Router tworzony raz — nie w build, by zmiana locale nie resetowała nawigacji.
  final GoRouter _router = createRouter();

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
