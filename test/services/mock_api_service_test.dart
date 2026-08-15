import 'package:flutter_test/flutter_test.dart';

import 'package:benedictum_mobile/services/mocks/mock_api_service.dart';

void main() {
  group('MockApiService', () {
    test('getPersonaResponses zwraca 3 odpowiedzi person (offline)', () async {
      final service = MockApiService();

      final responses = await service.getPersonaResponses(
        userInput: 'Mam gotowe MVP.',
        scenario: 'pitch',
      );

      expect(responses, hasLength(3));
      expect(responses.map((m) => m.sender).toSet(), {
        'critic',
        'optimist',
        'coach',
      });
      expect(responses.every((m) => m.content.isNotEmpty), isTrue);
    });

    test('odpowiedzi mają unikalne id i znacznik czasu', () async {
      final service = MockApiService();
      final responses = await service.getPersonaResponses(
        userInput: 'Test',
        scenario: 'pitch',
      );

      final ids = responses.map((m) => m.id).toSet();
      expect(ids, hasLength(3));
      expect(responses.every((m) => m.timestamp.isAfter(DateTime(2020))), isTrue);
    });

    test('tryb intake: zwraca wyłącznie 1 odpowiedź Coacha', () async {
      final service = MockApiService();

      final responses = await service.getPersonaResponses(
        userInput: 'Mam gotowe MVP.',
        scenario: 'pitch',
        mode: 'intake',
      );

      expect(responses, hasLength(1));
      expect(responses.single.sender, 'coach');
      expect(responses.single.content.isNotEmpty, isTrue);
    });

    test('tryb analyze: przekazuje context i zwraca 3 odpowiedzi', () async {
      final service = MockApiService();

      final responses = await service.getPersonaResponses(
        userInput: 'Mam gotowe MVP.',
        scenario: 'pitch',
        context: 'USER_STATEMENT 1: Mam gotowe MVP.',
        mode: 'analyze',
      );

      expect(responses, hasLength(3));
      expect(responses.map((m) => m.sender).toSet(), {
        'critic',
        'optimist',
        'coach',
      });
    });
  });
}
