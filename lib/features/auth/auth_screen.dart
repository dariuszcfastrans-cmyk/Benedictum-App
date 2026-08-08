import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:benedictum_mobile/l10n/app_localizations.dart';

import '../../config/routes.dart';
import '../../core/errors/app_exceptions.dart';
import '../../services/interfaces/i_auth_service.dart';
import '../../services/mocks/mock_auth_service.dart';
import '../../services/onesignal_service.dart';
import '../../services/revenuecat_service.dart';
import '../../services/service_locator.dart';

/// Ekran autoryzacji — C1: formularz email + hasło na IAuthService.
/// Tryb logowania (signIn) lub rejestracji (signUp) przełączany w UI.
/// Po sukcesie → /home.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.authService});

  /// Wstrzykiwana usługa autoryzacji; domyślnie MockAuthService (C1).
  final IAuthService? authService;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Priorytet: parametr → rejestr (ServiceLocator) → Mock (fallback offline).
  late final IAuthService _authService =
      widget.authService ?? ServiceLocator.authService ?? MockAuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isRegisterMode = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Email i hasło są wymagane.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = _isRegisterMode
          ? await _authService.signUp(email: email, password: password)
          : await _authService.signIn(email: email, password: password);

      if (!mounted) return;
      if (_isRegisterMode && !result.isEmailConfirmed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Konto utworzone. Potwierdź e-mail, aby dokończyć.'),
          ),
        );
      }
      await _syncSubscription(result.user.id);
      if (!mounted) return;
      context.go(AppRoutes.home);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Nieznany błąd logowania.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Po zalogowaniu: wiąże userId z RevenueCat oraz ustawia tagi OneSignal
  /// ({user_id, tier}). Błędy poszczególnych SDK nie blokują nawigacji.
  Future<void> _syncSubscription(String userId) async {
    try {
      await RevenueCatService.instance.setUserId(userId);
    } catch (_) {}
    try {
      final hasPro = await RevenueCatService.instance.checkProAccess();
      await OneSignalService.instance.setTags(
        userId: userId,
        tier: hasPro ? 'pro' : 'free',
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.authTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.authEmail,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.authPassword,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: Text(_isRegisterMode ? l10n.authRegister : l10n.authLogin),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() => _isRegisterMode = !_isRegisterMode),
                  child: Text(
                    _isRegisterMode
                        ? l10n.authSwitchToLogin
                        : l10n.authSwitchToRegister,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
