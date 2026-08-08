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
  });
}
