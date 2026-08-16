import '../../models/message.dart';
import '../../models/report.dart';
import '../../models/session_summary.dart';

/// Interfejs serwisu API rady doradczej (persony + Gemini).
/// Implementacja mockowa w C1 (offline); Edge Function + Gemini w C2.
abstract interface class IApiService {
  /// Zwraca 3 odpowiedzi person dla podanego argumentu użytkownika
  /// w kontekście scenariusza.
  /// [context] — opcjonalny, ustrukturyzowany kontekst zebrany przez Coacha.
  /// [mode] — tryb rozmowy: "intake" (tylko Coach, wywiad) lub "analyze".
  Future<List<Message>> getPersonaResponses({
    required String userInput,
    required String scenario,
    String? context,
    String? mode,
  });

  /// Generuje raport końcowy sesji (mode:"report" — 1 wywołanie LLM).
  /// [scenario] — identyfikator scenariusza.
  /// [context] — wypowiedzi użytkownika (USER_STATEMENT) zebrane w sesji.
  Future<Report> getReport({
    required String scenario,
    required String context,
  });

  /// Zapisuje zakończoną sesję (autosave, Fala 2A.3): raport + wypowiedzi
  /// użytkownika przez session-proxy (POST /sessions). Zwraca id sesji.
  /// Serwer wymusza sender='user' i waliduje kontrakt raportu (422).
  Future<String> saveSession({
    required String scenarioKey,
    String? title,
    required List<String> userStatements,
    required Report report,
  });

  /// Historia własnych sesji (GET /sessions) — malejąco, retencja 90 dni.
  Future<List<SessionSummary>> getSessionHistory();

  /// Odczyt raportu zapisanej sesji (GET /sessions/:id). Rzuca
  /// [SessionUnavailableException], gdy sesja niedostępna (404 / ownership).
  Future<(SessionSummary, Report?)> getSessionReport(String sessionId);

  /// Usuwa własną sesję (DELETE /sessions/:id) — kaskada messages+reports.
  /// Rzuca [SessionUnavailableException] dla obcej/nieistniejącej sesji.
  Future<void> deleteSession(String sessionId);
}
