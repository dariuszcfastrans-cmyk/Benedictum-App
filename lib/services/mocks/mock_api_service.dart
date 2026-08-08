import 'dart:math';

import '../../models/message.dart';
import '../../models/persona.dart';
import '../interfaces/i_api_service.dart';

/// Mock serwisu API — Część C1.
/// UWAGA: 100% lokalny mock, ZERO połączeń sieciowych (http/dio/socket).
/// Do podpięcia prawdziwego backendu (Edge Function + Gemini) w części C2.
class MockApiService implements IApiService {
  MockApiService();

  final Random _random = Random();

  /// Zwraca 3 odpowiedzi person (Krytyk, Optymista, Coach).
  /// Opóźnienie 500 ms per odpowiedź, symulowane lokalnie.
  @override
  Future<List<Message>> getPersonaResponses({
    required String userInput,
    required String scenario,
  }) async {
    final responses = <Message>[];

    for (final persona in Persona.values) {
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
}
