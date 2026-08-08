/// Wyjątki aplikacji Benedictum.
/// Klasy puste na etapie Części A — rozwijane w części C (logika sieciowa).
library;

/// Błąd komunikacji z API.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}

/// Błąd autoryzacji/logowania.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

/// Błąd przekroczenia limitu zapytań (rate limit).
class RateLimitException implements Exception {
  final String message;
  RateLimitException(this.message);

  @override
  String toString() => 'RateLimitException: $message';
}
