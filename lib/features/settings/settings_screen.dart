import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:benedictum_mobile/l10n/app_localizations.dart';

import '../../config/locale_controller.dart';
import '../../config/routes.dart';

/// Ekran ustawień: wybór języka (bez restartu), o aplikacji, wyloguj (placeholder).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
            onPressed: () => context.go(AppRoutes.splash),
            icon: const Icon(Icons.logout),
            label: Text(l10n.settingsLogout),
          ),
        ],
      ),
    );
  }
}
