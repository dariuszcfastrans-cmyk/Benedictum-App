import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../core/errors/app_exceptions.dart';
import '../models/message.dart';
import '../models/persona.dart';
import '../models/report.dart';
import '../models/session_summary.dart';
import 'interfaces/i_api_service.dart';

/// Implementacja IApiService na Supabase Edge Function (Część C2).
/// Wywołuje funkcję 'llm-gateway' przez functions.invoke (nie http.post).
/// Mapowanie błędów: 401 → AuthException, 429 → RateLimitException,
/// 422 → ApiException, 503 → ApiException.
class SupabaseApiService implements IApiService {
  SupabaseApiService();

  /// Runtime switch (KROK 7): nazwa funkcji LLM czytana w runtime, nie w build time.
  /// Priorytet: (1) override kompilacji SUPABASE_LLM_FUNCTION (dev),
  /// (2) domyślnie llm-gateway (od KROKU 8 jedyny host LLM — legacy proxy usunięte).
  static const String _compileTimeLlmFunction = String.fromEnvironment(
    'SUPABASE_LLM_FUNCTION',
  );

  String _llmFunctionName =
      _compileTimeLlmFunction.isNotEmpty ? _compileTimeLlmFunction : 'llm-gateway';

  /// Przełącza nazwę funkcji LLM w runtime (bez przebudowy aplikacji) — KROK 7.
  void useLlmFunction(String functionName) {
    if (functionName.isNotEmpty) _llmFunctionName = functionName;
  }

  /// Osobna funkcja persistencji (Nota N2) — Fala 2A.2/2A.3.
  static const String _sessionFunctionName = 'session-proxy';

  FunctionsClient get _functions => Supabase.instance.client.functions;

  /// Wywołanie funkcji LLM (KROK 8: bez fallbacku legacy — llm-gateway jedynym hostem).
  Future<Map<String, dynamic>> _invokeLlm(Map<String, dynamic> body) async {
    final response = await _functions.invoke(_llmFunctionName, body: body);
    final data = response.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return const <String, dynamic>{};
  }

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
      final data = await _invokeLlm({
        'persona': isIntake ? 'coach' : null,
        'message': userInput,
        'scenario': scenario,
        'context': context,
        'mode': mode,
      });

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

  /// Generuje raport końcowy sesji (mode:"report" — 1 wywołanie LLM).
  /// Odpowiedź JSON: { report: { strengths, gaps, action_items, overall_rating } }.
  @override
  Future<Report> getReport({
    required String scenario,
    required String context,
  }) async {
    try {
      final data = await _invokeLlm({
        'mode': 'report',
        'scenario': scenario,
        'context': context,
      });

      final reportJson = data['report'];
      if (reportJson is! Map) {
        throw ApiException('Nieprawidłowy format raportu (422).');
      }
      return Report.fromJson(Map<String, dynamic>.from(reportJson));
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

  /// Mapowanie błędów session-proxy: 404/403 → niedostępna sesja (ownership).
  Exception _mapSessionException(FunctionException e) {
    if (e.status == 404 || e.status == 403) {
      return SessionUnavailableException(
        'Sesja jest niedostępna (${e.status}). Możliwy brak dostępu '
        'lub usunięcie.',
      );
    }
    return _mapFunctionException(e);
  }

  @override
  Future<String> saveSession({
    required String scenarioKey,
    String? title,
    required List<String> userStatements,
    required Report report,
  }) async {
    try {
      final response = await _functions.invoke(
        '$_sessionFunctionName/sessions',
        body: {
          'scenario_key': scenarioKey,
          'title': title,
          'user_statements': userStatements,
          'report': {
            'strengths': report.strengths,
            'gaps': report.gaps,
            'action_items': report.actionItems,
            'overall_rating': report.overallRating,
          },
        },
      );
      final data = (response.data as Map?) ?? const <String, dynamic>{};
      final id = data['session_id']?.toString();
      if (id == null || id.isEmpty) {
        throw ApiException('Serwer nie zwrócił identyfikatora sesji.');
      }
      return id;
    } on FunctionException catch (e) {
      throw _mapSessionException(e);
    } on ApiException {
      rethrow;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw ApiException('Błąd komunikacji z serwerem: ${e.runtimeType}');
    }
  }

  @override
  Future<List<SessionSummary>> getSessionHistory() async {
    try {
      final response = await _functions.invoke(
        '$_sessionFunctionName/sessions',
        method: HttpMethod.get,
      );
      final data = (response.data as Map?) ?? const <String, dynamic>{};
      final raw = data['sessions'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => SessionSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on FunctionException catch (e) {
      throw _mapSessionException(e);
    } on ApiException {
      rethrow;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw ApiException('Błąd komunikacji z serwerem: ${e.runtimeType}');
    }
  }

  @override
  Future<(SessionSummary, Report?)> getSessionReport(String sessionId) async {
    try {
      final response = await _functions.invoke(
        '$_sessionFunctionName/sessions/$sessionId',
        method: HttpMethod.get,
      );
      final data = (response.data as Map?) ?? const <String, dynamic>{};
      final sessionJson = data['session'];
      if (sessionJson is! Map) {
        throw SessionUnavailableException('Brak danych sesji.');
      }
      final session = SessionSummary.fromJson(
        Map<String, dynamic>.from(sessionJson),
      );

      final reportJson = data['report'];
      Report? report;
      if (reportJson is Map) {
        report = Report.fromJson(Map<String, dynamic>.from(reportJson));
      }
      return (session, report);
    } on FunctionException catch (e) {
      throw _mapSessionException(e);
    } on SessionUnavailableException {
      rethrow;
    } on ApiException {
      rethrow;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw ApiException('Błąd komunikacji z serwerem: ${e.runtimeType}');
    }
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    try {
      await _functions.invoke(
        '$_sessionFunctionName/sessions/$sessionId',
        method: HttpMethod.delete,
      );
    } on FunctionException catch (e) {
      throw _mapSessionException(e);
    } on SessionUnavailableException {
      rethrow;
    } on ApiException {
      rethrow;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw ApiException('Błąd komunikacji z serwerem: ${e.runtimeType}');
    }
  }
}
