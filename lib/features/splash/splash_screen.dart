import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:benedictum_mobile/l10n/app_localizations.dart';

import '../../config/routes.dart';
import '../../services/interfaces/i_auth_service.dart';
import '../../services/service_locator.dart';

/// Ekran startowy: logo, appTitle, fade-in, przycisk „Przejdź dalej" → /auth.
/// UX: jeśli istnieje trwała sesja (persistSession Supabase), automatycznie
/// pomija /auth i przechodzi do /home — użytkownik nie loguje się za każdym
/// otwarciem aplikacji.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.authService});

  /// Wstrzykiwana usługa autoryzacji; domyślnie z ServiceLocator (C2).
  final IAuthService? authService;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final IAuthService? _authService =
      widget.authService ?? ServiceLocator.authService;
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
    _checkSession();
  }

  /// Trwała sesja (currentUser != null) → /home bez logowania.
  /// Brak sesji → standardowy przepływ do /auth.
  void _checkSession() {
    if (_authService?.currentUser != null) {
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (mounted) context.go(AppRoutes.home);
      });
    }
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
