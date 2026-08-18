import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:benedictum_mobile/l10n/app_localizations.dart';

import '../../config/locale_controller.dart';
import '../../config/routes.dart';
import '../../services/interfaces/i_auth_service.dart';
import '../../services/interfaces/i_revenuecat_service.dart';
import '../../services/revenuecat_service.dart';
import '../../services/service_locator.dart';

/// Ekran ustawień: wybór języka (bez restartu), o aplikacji, subskrypcja,
/// wyloguj (czyści sesję Supabase i wraca do splash).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.revenueCatService, this.authService});

  /// Wstrzykiwany serwis RevenueCat; domyślnie singleton.
  final IRevenueCatService? revenueCatService;

  /// Wstrzykiwana usługa autoryzacji; domyślnie z ServiceLocator (C2).
  final IAuthService? authService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final IRevenueCatService _revenueCatService =
      widget.revenueCatService ?? RevenueCatService.instance;
  late final IAuthService? _authService =
      widget.authService ?? ServiceLocator.authService;

  bool _checkingAccess = true;
  bool _hasPro = false;
  DateTime? _expiry;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionInfo();
  }

  /// Pobiera status subskrypcji Pro (tier + data wygaśnięcia).
  Future<void> _loadSubscriptionInfo() async {
    if (!_revenueCatService.isInitialized) {
      if (mounted) setState(() => _checkingAccess = false);
      return;
    }
    final hasPro = await _revenueCatService.checkProAccess();
    final expiry = hasPro ? await _revenueCatService.getProExpiryDate() : null;
    if (!mounted) return;
    setState(() {
      _checkingAccess = false;
      _hasPro = hasPro;
      _expiry = expiry;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.settingsLanguage,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<Locale>(
            valueListenable: LocaleController.instance.locale,
            builder: (context, locale, _) {
              return DropdownButtonFormField<Locale>(
                initialValue: locale,
                items: const [
                  DropdownMenuItem(value: Locale('pl'), child: Text('Polski')),
                  DropdownMenuItem(value: Locale('en'), child: Text('English')),
                  DropdownMenuItem(value: Locale('fr'), child: Text('Français')),
                  DropdownMenuItem(value: Locale('es'), child: Text('Español')),
                ],
                onChanged: (newLocale) {
                  if (newLocale == null) return;
                  // Przełączenie locale bez restartu procesu aplikacji.
                  LocaleController.instance.locale.value = newLocale;
                },
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            l10n.settingsSubscription,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                _checkingAccess
                    ? null
                    : (_hasPro ? Icons.workspace_premium : Icons.lock_outline),
              ),
              title: Text(
                _checkingAccess
                    ? '...'
                    : _hasPro
                        ? l10n.settingsTierPro
                        : l10n.settingsTierFree,
              ),
              subtitle: Text(
                _checkingAccess
                    ? '...'
                    : _hasPro && _expiry != null
                        ? '${l10n.settingsExpiry}: ${_formatDate(_expiry!)}'
                        : _hasPro
                            ? l10n.settingsExpiry
                            : '${l10n.settingsTier}: ${l10n.settingsTierFree}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => context.go(AppRoutes.paywall),
                tooltip: l10n.settingsManage,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.settingsAbout,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Benedictum'),
              subtitle: Text('v0.1.0 · DCI Veridictum Lab'),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: Text(l10n.settingsLogout),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _confirmDeleteAccount,
            icon: const Icon(Icons.delete_forever),
            label: Text(l10n.settingsDeleteAccount),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  /// Wylogowanie: czyści sesję Supabase i wraca do splash (gdzie przy braku
  /// sesji pokaże się /auth). Brak usługi auth (offline/Mock) → sam nawiguje.
  Future<void> _logout() async {
    try {
      await _authService?.signOut();
    } catch (_) {
      // Nawet gdy signOut rzuci błąd, wracamy do splash.
    }
    if (!mounted) return;
    context.go(AppRoutes.splash);
  }

  /// Potwierdzenie usunięcia konta (wymóg Google Play: jawne potwierdzenie
  /// przed trwałą operacją). Po powodzeniu wracamy do splash.
  Future<void> _confirmDeleteAccount() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsDeleteTitle),
        content: Text(l10n.settingsDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.settingsDeleteCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.settingsDeleteConfirm,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _authService?.deleteAccount();
      if (!mounted) return;
      context.go(AppRoutes.splash);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsDeleteError)),
      );
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$day.$month.${local.year}';
  }
}
