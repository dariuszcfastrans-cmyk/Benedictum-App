import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:benedictum_mobile/l10n/app_localizations.dart';

import '../config/routes.dart';

/// Ekran startowy. W części A: tylko przycisk „Przejdź dalej".
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.appTitle,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => context.go(AppRoutes.home),
              child: Text(l10n.splashContinue),
            ),
          ],
        ),
      ),
    );
  }
}
