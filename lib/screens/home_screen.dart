import 'package:flutter/material.dart';
import 'package:benedictum_mobile/l10n/app_localizations.dart';

/// Ekran główny. W części A: tylko AppBar z tytułem z ARB.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTitle)),
      body: const Center(
        child: Text('Home'),
      ),
    );
  }
}
