import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:benedictum_mobile/l10n/app_localizations.dart';

import '../../config/routes.dart';
import '../../models/scenario.dart';

/// Ekran główny: lista scenariuszy + przycisk ustawień.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const scenario = Scenario(id: 'pitch_investor', titleKey: 'scenarioPitchTitle');

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go(AppRoutes.settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.homeScenarios,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.business_center),
              title: Text(l10n.scenarioPitchTitle),
              subtitle: Text(l10n.scenarioPitchSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(AppRoutes.chat, extra: scenario),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.homeHistory,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history),
              title: Text(l10n.homeHistoryTitle),
              subtitle: Text(l10n.homeHistorySubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(AppRoutes.history),
            ),
          ),
        ],
      ),
    );
  }
}
