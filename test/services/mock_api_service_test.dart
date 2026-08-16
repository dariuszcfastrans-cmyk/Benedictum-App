import 'package:flutter_test/flutter_test.dart';

import 'package:benedictum_mobile/core/errors/app_exceptions.dart';
import 'package:benedictum_mobile/models/report.dart';
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

    test('getReport zwraca kompletny kontrakt raportu (Fala 2A)', () async {
      final service = MockApiService();

      final report = await service.getReport(
        scenario: 'pitch',
        context: 'USER_STATEMENT 1: Mam gotowe MVP.',
      );

      expect(report.strengths, isNotEmpty);
      expect(report.gaps, isNotEmpty);
      expect(report.actionItems, isNotEmpty);
      expect(report.overallRating, inInclusiveRange(1, 5));
      expect(report.strengths.every((s) => s.isNotEmpty), isTrue);
    });
  });

  group('MockApiService historia (Fala 2A.3)', () {
    Report sampleReport() => const Report(
          strengths: ['Mocna analiza (zapisana)'],
          gaps: ['Ryzyko kosztów'],
          actionItems: ['Weryfikacja liczb'],
          overallRating: 4,
        );

    test('saveSession zwraca id i zapisuje sesję w historii', () async {
      final service = MockApiService();

      final id = await service.saveSession(
        scenarioKey: 'pitch',
        title: 'Pitch do inwestora',
        userStatements: ['Mam gotowe MVP.'],
        report: sampleReport(),
      );

      expect(id, isNotEmpty);
      final history = await service.getSessionHistory();
      expect(history, hasLength(1));
      expect(history.single.id, id);
      expect(history.single.scenarioKey, 'pitch');
      expect(history.single.status, 'completed');
      expect(history.single.completedAt, isNotNull);
    });

    test('historia zwraca sesje najnowsze pierwsze', () async {
      final service = MockApiService();

      await service.saveSession(
        scenarioKey: 'pitch',
        title: 'Pierwsza',
        userStatements: const ['A'],
        report: sampleReport(),
      );
      await service.saveSession(
        scenarioKey: 'negotiation',
        title: 'Druga',
        userStatements: const ['B'],
        report: sampleReport(),
      );

      final history = await service.getSessionHistory();
      expect(history, hasLength(2));
      expect(history.first.title, 'Druga');
      expect(history.last.title, 'Pierwsza');
    });

    test('getSessionReport zwraca sesję + raport dla zapisanej sesji', () async {
      final service = MockApiService();

      final id = await service.saveSession(
        scenarioKey: 'pitch',
        title: 'Pitch do inwestora',
        userStatements: ['Mam gotowe MVP.'],
        report: sampleReport(),
      );

      final (session, report) = await service.getSessionReport(id);
      expect(session.id, id);
      expect(report, isNotNull);
      expect(report!.overallRating, 4);
    });

    test('getSessionReport dla nieistniejącej sesji → SessionUnavailable', () async {
      final service = MockApiService();

      expect(
        () => service.getSessionReport('mock_999'),
        throwsA(isA<SessionUnavailableException>()),
      );
    });

    test('deleteSession usuwa sesję z historii', () async {
      final service = MockApiService();

      final id = await service.saveSession(
        scenarioKey: 'pitch',
        title: 'Pitch do inwestora',
        userStatements: ['Mam gotowe MVP.'],
        report: sampleReport(),
      );

      await service.deleteSession(id);
      final history = await service.getSessionHistory();
      expect(history, isEmpty);
    });

    test('deleteSession dla nieistniejącej sesji → SessionUnavailable', () async {
      final service = MockApiService();

      expect(
        () => service.deleteSession('mock_999'),
        throwsA(isA<SessionUnavailableException>()),
      );
    });
  });
}
