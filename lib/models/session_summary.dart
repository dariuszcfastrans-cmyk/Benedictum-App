/// Podsumowanie sesji z historii (kontrakt Dyrektywy 2A §15/§17).
/// Odpowiedź session-proxy GET /sessions: { id, scenario_key, title, status,
/// created_at, completed_at }. Pola pochodzą z bazy — traktowane jako tekst
/// (untrusted input, §22), render bez interpretacji.
class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.scenarioKey,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.completedAt,
  });

  final String id;
  final String? scenarioKey;
  final String? title;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;

  factory SessionSummary.fromJson(Map<String, dynamic> json) {
    return SessionSummary(
      id: json['id']?.toString() ?? '',
      scenarioKey: json['scenario_key'] as String?,
      title: json['title'] as String?,
      status: json['status']?.toString() ?? 'active',
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      completedAt: _parseDate(json['completed_at']),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}