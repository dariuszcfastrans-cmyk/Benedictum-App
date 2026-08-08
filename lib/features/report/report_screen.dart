import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:benedictum_mobile/l10n/app_localizations.dart';

import '../../config/routes.dart';

/// Ekran raportu po sesji: mocne strony, luki i ryzyka, wskazówki.
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ReportSection(
            icon: Icons.check_circle,
            color: Colors.green,
            title: l10n.reportStrengths,
            items: const ['Jasna wizja produktu', 'Znajomość odbiorcy'],
          ),
          const SizedBox(height: 16),
          _ReportSection(
            icon: Icons.warning,
            color: Colors.red,
            title: l10n.reportRisks,
            items: const ['Brak twardych liczb rynkowych', 'Niedoprecyzowany model płatności'],
          ),
          const SizedBox(height: 16),
          _ReportSection(
            icon: Icons.lightbulb,
            color: Colors.teal,
            title: l10n.reportTips,
            items: const ['Przygotuj jedną liczbę rynku', 'Odpowiedz na „kto już to zrobił?"'],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go(AppRoutes.home),
            icon: const Icon(Icons.save),
            label: Text(l10n.reportSaveHistory),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              // Placeholder — RevenueCat w części D.
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.reportUnlockMore)),
              );
            },
            child: Text(l10n.reportUnlockMore),
          ),
        ],
      ),
    );
  }
}

/// Sekcja raportu z ikoną, kolorem i listą punktów.
class _ReportSection extends StatelessWidget {
  const _ReportSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final Color color;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('• $item'),
              ),
          ],
        ),
      ),
    );
  }
}
