import '../../models/message.dart';

/// Interfejs serwisu API rady doradczej (persony + Gemini).
/// Implementacja mockowa w C1 (offline); Edge Function + Gemini w C2.
abstract interface class IApiService {
  /// Zwraca 3 odpowiedzi person dla podanego argumentu użytkownika
  /// w kontekście scenariusza.
  Future<List<Message>> getPersonaResponses({
    required String userInput,
    required String scenario,
  });
}
