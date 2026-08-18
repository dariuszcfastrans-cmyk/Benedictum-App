import 'package:flutter/material.dart';

/// Persony wirtualnej rady doradczej Benedictum — kontrakt dla warstwy UI.
/// D1: System Prompty stanowią własność intelektualną produktu i żyją
/// wyłącznie w Edge Functions (supabase/functions/_shared/prompts/).
/// Ten model trzyma tylko metadane UI — ZERO treści system promptów.
enum Persona {
  critic(
    senderId: 'critic',
    nameKey: 'critic',
    displayName: 'Krytyk',
    color: Color(0xFFD32F2F),
    icon: Icons.psychology,
  ),
  optimist(
    senderId: 'optimist',
    nameKey: 'optimist',
    displayName: 'Optymista',
    color: Color(0xFF388E3C),
    icon: Icons.wb_sunny,
  ),
  coach(
    senderId: 'coach',
    nameKey: 'coach',
    displayName: 'Coach',
    color: Color(0xFF1976D2),
    icon: Icons.flag,
  );

  const Persona({
    required this.senderId,
    required this.nameKey,
    required this.displayName,
    required this.color,
    required this.icon,
  });

  /// Identyfikator nadawcy w modelu Message ('user', 'critic', 'optimist', 'coach').
  final String senderId;

  /// Klucz ARB do nazwy persony.
  final String nameKey;

  /// Nazwa wyświetlana w UI.
  final String displayName;

  /// Kolor akcentu persony w UI.
  final Color color;

  /// Ikona persony w UI.
  final IconData icon;
}
