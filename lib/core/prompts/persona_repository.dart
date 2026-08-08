import 'package:flutter/material.dart';

import 'persona_metadata.dart';
import 'persona_type.dart';

/// Repozytorium metadanych person dla UI.
/// D1: jedyne miejsce, z którego ekrany pobierają nazwy, kolory, ikony i opisy
/// person. ZERO treści system promptów (te żyją w Edge Function).
class PersonaRepository {
  const PersonaRepository._();

  /// Dokładnie 3 persony: Krytyk, Optymista, Coach.
  static const List<PersonaMetadata> personas = [
    PersonaMetadata(
      type: PersonaType.critic,
      displayName: 'Krytyk',
      color: Color(0xFFD32F2F),
      icon: Icons.psychology,
      description: 'identyfikuje luki, ryzyka i słabe punkty',
    ),
    PersonaMetadata(
      type: PersonaType.optimist,
      displayName: 'Optymista',
      color: Color(0xFF388E3C),
      icon: Icons.wb_sunny,
      description: 'wskazuje mocne strony i szanse',
    ),
    PersonaMetadata(
      type: PersonaType.coach,
      displayName: 'Coach',
      color: Color(0xFF1976D2),
      icon: Icons.flag,
      description: 'przekształca analizę w konkretne kroki',
    ),
  ];

  /// Wyszukiwanie persony po senderId ('critic' | 'optimist' | 'coach').
  /// Zwraca null, jeśli senderId nie należy do persony (np. 'user').
  static PersonaMetadata? bySenderId(String senderId) {
    for (final persona in personas) {
      if (persona.senderId == senderId) return persona;
    }
    return null;
  }
}
