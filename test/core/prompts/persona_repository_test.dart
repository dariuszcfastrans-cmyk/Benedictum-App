import 'package:flutter_test/flutter_test.dart';

import 'package:benedictum_mobile/core/prompts/persona_metadata.dart';
import 'package:benedictum_mobile/core/prompts/persona_repository.dart';
import 'package:benedictum_mobile/core/prompts/persona_type.dart';

void main() {
  group('PersonaRepository (kontrakt metadanych — aneks D1)', () {
    test('zwraca dokładnie 3 persony', () {
      expect(PersonaRepository.personas, hasLength(3));
    });

    test('metadane są kompletne i NIE zawierają treści system promptów', () {
      for (final PersonaMetadata m in PersonaRepository.personas) {
        expect(m.senderId, isNotEmpty);
        expect(m.nameKey, isNotEmpty);
        expect(m.displayName, isNotEmpty);
        expect(m.description, isNotEmpty);
        expect(m.color, isNotNull);
        expect(m.icon, isNotNull);

        // Kontrakt D1: metadane nie zawierają treści system promptów.
        final metadataText =
            '${m.senderId} ${m.nameKey} ${m.displayName} ${m.description}';
        expect(metadataText.toLowerCase(), isNot(contains('jesteś krytykiem')));
        expect(metadataText.toLowerCase(), isNot(contains('jesteś optymistą')));
        expect(metadataText.toLowerCase(), isNot(contains('jesteś coachem')));
        expect(metadataText.toLowerCase(), isNot(contains('twoja rola')));
      }
    });

    test('dokładnie 3 unikalne typy person', () {
      final types = PersonaRepository.personas.map((m) => m.type).toSet();
      expect(types, {
        PersonaType.critic,
        PersonaType.optimist,
        PersonaType.coach,
      });
    });

    test('bySenderId zwraca personę po senderId, null dla user', () {
      expect(PersonaRepository.bySenderId('critic')?.type, PersonaType.critic);
      expect(
        PersonaRepository.bySenderId('optimist')?.type,
        PersonaType.optimist,
      );
      expect(PersonaRepository.bySenderId('coach')?.type, PersonaType.coach);
      expect(PersonaRepository.bySenderId('user'), isNull);
    });
  });
}
