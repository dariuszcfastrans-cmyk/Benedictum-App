import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/routes.dart';
import '../l10n/app_localizations.dart';
import '../services/interfaces/i_revenuecat_service.dart';
import '../services/revenuecat_service.dart';

/// Ekran płatności (paywall) — Część D2.
/// Ładuje offering 'default' z RevenueCat i pokazuje 3 plany
/// (Monthly, Six Month, Yearly) z przyciskami Subskrybuj / Przywróć zakupy.
/// Brak klucza / brak oferty → komunikat o błędzie + przycisk ponowienia.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, this.revenueCatService});

  /// Wstrzykiwany serwis RevenueCat; domyślnie singleton.
  final IRevenueCatService? revenueCatService;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late final IRevenueCatService _service =
      widget.revenueCatService ?? RevenueCatService.instance;

  bool _loading = true;
  String? _error;
  List<Package> _packages = [];
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  /// Pobiera offering 'default' (lub current) i wybiera 3 pakiety:
  /// monthly, sixMonth, annual. Pozostałe pomija.
  Future<void> _loadOfferings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final offerings = await _service.getOfferings();
    if (!mounted) return;

    final offering = offerings?.current;
    final packages = offering?.availablePackages ?? [];
    final selected = <Package>[];
    for (final type in const [
      PackageType.monthly,
      PackageType.sixMonth,
      PackageType.annual,
    ]) {
      final match = packages.where((p) => p.packageType == type).toList();
      if (match.isNotEmpty) selected.add(match.first);
    }

    setState(() {
      _loading = false;
      _packages = selected;
      if (selected.isEmpty) {
        _error = null; // brak planów — pokażemy komunikat o braku oferty
      }
    });
  }

  Future<void> _subscribe(Package package) async {
    setState(() => _purchasing = true);
    final customerInfo = await _service.purchasePackage(package);
    if (!mounted) return;
    setState(() => _purchasing = false);

    final l10n = AppLocalizations.of(context);
    final message = customerInfo != null &&
            customerInfo.entitlements.active
                .containsKey(RevenueCatService.proEntitlementId)
        ? l10n.paywallPurchaseSuccess
        : l10n.paywallPurchaseCancelled;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    if (customerInfo != null) {
      // Sukces zakupu — wróć do home.
      context.go(AppRoutes.home);
    }
  }

  Future<void> _restore() async {
    setState(() => _purchasing = true);
    final customerInfo = await _service.restorePurchases();
    if (!mounted) return;
    setState(() => _purchasing = false);

    final l10n = AppLocalizations.of(context);
    final hasPro = customerInfo != null &&
        customerInfo.entitlements.active
            .containsKey(RevenueCatService.proEntitlementId);
    final message =
        hasPro ? l10n.paywallRestoreSuccess : l10n.paywallRestoreNone;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    if (hasPro) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.paywallTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _purchasing ? null : () => context.go(AppRoutes.home),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _loadOfferings)
                : _packages.isEmpty
                    ? _ErrorView(
                        message: l10n.paywallError, onRetry: _loadOfferings)
                    : _buildPlans(l10n),
      ),
    );
  }

  Widget _buildPlans(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Icon(
          Icons.workspace_premium,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.paywallTitle,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.paywallSubtitle,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ..._packages.map((p) => _PlanCard(
              package: p,
              purchasing: _purchasing,
              onSubscribe: () => _subscribe(p),
            )),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _purchasing ? null : _restore,
          child: Text(l10n.paywallRestore),
        ),
      ],
    );
  }
}

/// Karta pojedynczego planu: nazwa, cena, przycisk subskrypcji.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.package,
    required this.purchasing,
    required this.onSubscribe,
  });

  final Package package;
  final bool purchasing;
  final VoidCallback onSubscribe;

  String _periodLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (package.packageType) {
      case PackageType.monthly:
        return l10n.paywallMonthly;
      case PackageType.sixMonth:
        return l10n.paywallSixMonth;
      case PackageType.annual:
        return l10n.paywallYearly;
      default:
        return package.storeProduct.title;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: Text(_periodLabel(context)),
        subtitle: Text(package.storeProduct.priceString),
        trailing: FilledButton(
          onPressed: purchasing ? null : onSubscribe,
          child: Text(AppLocalizations.of(context).paywallSubscribe),
        ),
      ),
    );
  }
}

/// Widok błędu / braku oferty z przyciskiem ponowienia.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.paywallRetry),
            ),
          ],
        ),
      ),
    );
  }
}
