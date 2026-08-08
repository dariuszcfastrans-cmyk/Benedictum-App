import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../core/errors/app_exceptions.dart';
import '../models/message.dart';
import '../models/persona.dart';
import 'interfaces/i_api_service.dart';

/// Implementacja IApiService na Supabase Edge Function (Część C2).
/// Wywołuje funkcję 'gemini-proxy' przez functions.invoke (nie http.post).
/// Mapowanie błędów: 401 → AuthException, 429 → RateLimitException,
/// 422 → ApiException, 503 → ApiException.
class SupabaseApiService implements IApiService {
  SupabaseApiService();

  FunctionsClient get _functions => Supabase.instance.client.functions;

  @override
  Future<List<Message>> getPersonaResponses({
    required String userInput,
    required String scenario,
  }) async {
    try {
      final response = await _functions.invoke(
        'gemini-proxy',
        body: {
          'persona': null,
          'message': userInput,
          'scenario': scenario,
        },
      );

      // Odpowiedź JSON: { critic, optimist, coach } + remaining.
      final data = (response.data as Map?) ?? const <String, dynamic>{};

      final messages = <Message>[];
      for (final persona in Persona.values) {
        final content = data[persona.senderId];
        if (content is String && content.isNotEmpty) {
          messages.add(Message(
            id: '${persona.senderId}_${DateTime.now().microsecondsSinceEpoch}',
            sender: persona.senderId,
            content: content,
            timestamp: DateTime.now(),
          ));
        }
      }
      return messages;
    } on FunctionException catch (e) {
      throw _mapFunctionException(e);
    } on ApiException {
      rethrow;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw ApiException('Błąd komunikacji z serwerem: ${e.runtimeType}');
    }
  }

  /// Mapowanie statusu Edge Function na wyjątki domeny.
  Exception _mapFunctionException(FunctionException e) {
    switch (e.status) {
      case 401:
        return AuthException('Sesja wygasła. Zaloguj się ponownie.');
      case 429:
        return RateLimitException('Limit zapytań osiągnięty. Spróbuj za chwilę.');
      case 422:
        return ApiException('Nieprawidłowe dane zapytania (422).');
      case 503:
        return ApiException('Usługa niedostępna (503). Spróbuj później.');
      default:
        return ApiException('Błąd serwera (${e.status}).');
    }
  }
}
