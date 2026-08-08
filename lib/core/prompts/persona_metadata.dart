import 'package:flutter/material.dart';

import 'persona_type.dart';

/// Metadane UI persony — to, co widzi użytkownik w interfejsie.
/// D1: ZERO treści system promptów. Nazwa, kolor, ikona i opis roli.
class PersonaMetadata {
  const PersonaMetadata({
    required this.type,
    required this.displayName,
    required this.color,
    required this.icon,
    required this.description,
  });

  final PersonaType type;

  /// Nazwa wyświetlana (np. "Krytyk").
  final String displayName;

  /// Kolor akcentu persony.
  final Color color;

  /// Ikona persony.
  final IconData icon;

  /// Krótki opis roli widoczny w UI (np. "identyfikuje luki i ryzyka").
  final String description;

  String get senderId => type.senderId;
  String get nameKey => type.nameKey;
}
