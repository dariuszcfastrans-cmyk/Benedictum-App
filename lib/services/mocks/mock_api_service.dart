import 'dart:math';

import '../../core/errors/app_exceptions.dart';
import '../../models/message.dart';
import '../../models/persona.dart';
import '../../models/report.dart';
import '../../models/session_summary.dart';
import '../interfaces/i_api_service.dart';

/// Mock serwisu API — Część C1.
/// UWAGA: 100% lokalny mock, ZERO połączeń sieciowych (http/dio/socket).
/// Do podpięcia prawdziwego backendu (Edge Function + Gemini) w części C2.
class MockApiService implements IApiService {
  MockApiService();

  final Random _random = Random();

  /// Lokalna, nietrwała pamięć zapisanych sesji (Fala 2A.3 — historia).
  final List<SessionSummary> _savedSessions = [];

  /// Zwraca 3 odpowiedzi person (Krytyk, Optymista, Coach).
  /// Opóźnienie 500 ms per odpowiedź, symulowane lokalnie.
  @override
  Future<List<Message>> getPersonaResponses({
    required String userInput,
    required String scenario,
    String? context,
    String? mode,
  }) async {
    final responses = <Message>[];
    // W trybie "intake" mock odpowiada wyłącznie jako Coach (1 odpowiedź).
    final personas = mode == 'intake'
        ? const <Persona>[Persona.coach]
        : Persona.values;

    for (final persona in personas) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      responses.add(Message(
        id: '${persona.senderId}_${_random.nextInt(100000)}',
        sender: persona.senderId,
        content: _mockResponseFor(persona),
        timestamp: DateTime.now(),
      ));
    }

    return responses;
  }

  /// Generuje deterministyczny raport offline (kontrakt Dyrektywy 2A §3).
  /// Opóźnienie 500 ms symulowane lokalnie — spójne z getPersonaResponses.
  @override
  Future<Report> getReport({
    required String scenario,
    required String context,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return const Report(
      strengths: [
        'Jasna wizja produktu',
        'Znajomość odbiorcy',
      ],
      gaps: [
        'Brak twardych liczb rynkowych',
        'Niedoprecyzowany model płatności',
      ],
      actionItems: [
        'Przygotuj jedną liczbę rynku',
        'Odpowiedz na pytanie „kto już to zrobił?"',
      ],
      overallRating: 4,
    );
  }

  /// Hardcoded odpowiedzi mockowe — w części C2 zastąpione prawdziwym wywołaniem.
  String _mockResponseFor(Persona persona) {
    switch (persona) {
      case Persona.critic:
        return 'Gdzie masz dowód, że Twój rynek jest gotowy na ten produkt? '
            'Kto już to zrobił i ile to kosztowało?';
      case Persona.optimist:
        return 'Masz wyraźną wizję i konkretny punkt zaczepienia. To rzadkie '
            'w tym stadium — idziesz w dobrym kierunku.';
      case Persona.coach:
        return 'Dobry start. Na następny raz przygotuj jedną liczbę: szacowaną '
            'wielkość rynku. Przygotuję Cię, jak ją zaprezentować.';
    }
  }

  /// Zapisuje sesję w lokalnej pamięci mocka (deterministyczne id).
  @override
  Future<String> saveSession({
    required String scenarioKey,
    String? title,
    required List<String> userStatements,
    required Report report,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final id = 'mock_${_savedSessions.length + 1}';
    _savedSessions.insert(
      0,
      SessionSummary(
        id: id,
        scenarioKey: scenarioKey,
        title: title,
        status: 'completed',
        createdAt: DateTime.now(),
        completedAt: DateTime.now(),
      ),
    );
    return id;
  }

  /// Historia z lokalnej pamięci mocka (najnowsze pierwsze).
  @override
  Future<List<SessionSummary>> getSessionHistory() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return List.unmodifiable(_savedSessions);
  }

  /// Odczyt sesji + raport z lokalnej pamięci mocka.
  /// Sesja nieistniejąca → SessionUnavailableException (odpowiednik 404).
  @override
  Future<(SessionSummary, Report?)> getSessionReport(String sessionId) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final session = _savedSessions
        .where((s) => s.id == sessionId)
        .firstOrNull;
    if (session == null) {
      throw SessionUnavailableException('Sesja jest niedostępna (404).');
    }
    return (session, const Report(
      strengths: ['Mocna analiza (zapisana)'],
      gaps: ['Ryzyko kosztów'],
      actionItems: ['Weryfikacja liczb'],
      overallRating: 4,
    ));
  }

  /// Usuwa sesję z lokalnej pamięci mocka (symulacja kaskady).
  @override
  Future<void> deleteSession(String sessionId) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final before = _savedSessions.length;
    _savedSessions.removeWhere((s) => s.id == sessionId);
    if (_savedSessions.length == before) {
      throw SessionUnavailableException('Sesja jest niedostępna (404).');
    }
  }
}
