import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:benedictum_mobile/l10n/app_localizations.dart';

import '../../config/routes.dart';

/// Ekran startowy: logo, appTitle, fade-in, przycisk „Przejdź dalej" → /auth.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    // Efekt fade-in logo.
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() => _opacity = 1.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeIn,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.gavel,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.appTitle,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => context.go(AppRoutes.auth),
                child: Text(l10n.splashContinue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
