/// Stałe endpointów API aplikacji Benedictum.
/// UWAGA: bez żadnych kluczy API. Klucz Gemini żyje wyłącznie w Supabase Edge Function.
class ApiEndpoints {
  ApiEndpoints._();

  /// Bazowy adres API (ustawiany w konfiguracji środowiska).
  static const String baseUrl = 'https://placeholder.example.com';

  /// Ścieżka proxy do modelu Gemini w Supabase Edge Function.
  static const String geminiProxyPath = '/functions/v1/gemini-proxy';
}
