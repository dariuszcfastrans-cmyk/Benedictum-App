import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:benedictum_mobile/l10n/app_localizations.dart';

import 'config/routes.dart';
import 'config/theme.dart';

/// Główny widget aplikacji Benedictum.
class BenedictumApp extends StatelessWidget {
  const BenedictumApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      locale: const Locale('pl'),
      routerConfig: createRouter(),
    );
  }
}
