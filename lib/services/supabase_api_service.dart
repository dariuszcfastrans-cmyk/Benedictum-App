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
  static const String _llmFunctionName = String.fromEnvironment(
    'SUPABASE_LLM_FUNCTION',
    defaultValue: 'openrouter-proxy',
  );

  FunctionsClient get _functions => Supabase.instance.client.functions;

  @override
  Future<List<Message>> getPersonaResponses({
    required String userInput,
    required String scenario,
    String? context,
    String? mode,
  }) async {
    try {
      // Tryb "intake" prowadzi wyłącznie Coach (edge function ogranicza targety).
      final isIntake = mode == 'intake';
      final response = await _functions.invoke(
        _llmFunctionName,
        body: {
          'persona': isIntake ? 'coach' : null,
          'message': userInput,
          'scenario': scenario,
          'context': context,
          'mode': mode,
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
