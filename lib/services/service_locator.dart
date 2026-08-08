import 'interfaces/i_api_service.dart';
import 'interfaces/i_auth_service.dart';

/// Minimalny rejestr usług (Część C2).
/// main.dart wstrzykuje implementacje: Supabase* (online) lub Mock* (offline).
/// UI czyta z tego rejestru — dzięki temu zamiana backendu nie dotyka ekranów.
abstract final class ServiceLocator {
  static IAuthService? _authService;
  static IApiService? _apiService;

  /// Usługa autoryzacji; domyślnie null (fallback w UI na Mock).
  static IAuthService? get authService => _authService;

  /// Usługa API rady; domyślnie null (fallback w UI na Mock).
  static IApiService? get apiService => _apiService;

  static void register({
    IAuthService? authService,
    IApiService? apiService,
  }) {
    _authService = authService;
    _apiService = apiService;
  }
}
