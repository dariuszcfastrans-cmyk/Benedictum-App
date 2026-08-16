import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:benedictum_mobile/l10n/app_localizations.dart';

import '../../config/routes.dart';
import '../../models/report.dart';

/// Ekran raportu po sesji: mocne strony, luki i ryzyka, wskazówki, ocena.
/// Raport jest przekazywany przez GoRouter extra (generowany w ChatScreen przez
/// mode:"report"). Traktowany jako untrusted input — pola renderowane jako tekst.
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final extra = GoRouterState.of(context).extra;
    final report = extra is Report ? extra : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportTitle)),
      body: report == null
          ? _EmptyReport(l10n: l10n)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ReportRating(rating: report.overallRating, l10n: l10n),
                const SizedBox(height: 16),
                _ReportSection(
                  icon: Icons.check_circle,
                  color: Colors.green,
                  title: l10n.reportStrengths,
                  items: report.strengths,
                ),
                const SizedBox(height: 16),
                _ReportSection(
                  icon: Icons.warning,
                  color: Colors.red,
                  title: l10n.reportRisks,
                  items: report.gaps,
                ),
                const SizedBox(height: 16),
                _ReportSection(
                  icon: Icons.lightbulb,
                  color: Colors.teal,
                  title: l10n.reportTips,
                  items: report.actionItems,
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

/// Stan pusty: raport nie został wygenerowany (brak extra / bezpośrednia nawigacja).
class _EmptyReport extends StatelessWidget {
  const _EmptyReport({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          l10n.reportEmpty,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Ocena ogólna sesji (1–5).
class _ReportRating extends StatelessWidget {
  const _ReportRating({required this.rating, required this.l10n});

  final int rating;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.star, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.reportRating,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              '$rating/5',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
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
            if (items.isEmpty)
              Text(
                '—',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
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