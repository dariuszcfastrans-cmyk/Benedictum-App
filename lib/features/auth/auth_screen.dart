import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:benedictum_mobile/l10n/app_localizations.dart';

import '../../config/routes.dart';

/// Ekran autoryzacji — placeholder w części B.
/// Prawdziwe logowanie (Supabase Auth) w części C.
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authTitle)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: 24),
            Text(l10n.authTitle, style: Theme.of(context).textTheme.titleLarge),
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
