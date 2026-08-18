import '../../models/user.dart';

/// Interfejs usługi autoryzacji Benedictum.
/// Implementacja mockowa w C1 (offline); Supabase Auth w C2.
abstract interface class IAuthService {
  /// Rejestracja nowego konta. Zwraca wynik z flagą potwierdzenia e-maila.
  Future<AuthResult> signUp({
    required String email,
    required String password,
  });

  /// Logowanie istniejącego konta.
  Future<AuthResult> signIn({
    required String email,
    required String password,
  });

  /// Wylogowanie — czyści bieżącego użytkownika.
  Future<void> signOut();

  /// Trwałe usunięcie konta i wszystkich danych (wymóg Google Play / Galaxy Store).
  /// Po powodzeniu sesja jest zamknięta (stan: wylogowany).
  Future<void> deleteAccount();

  /// Aktualnie zalogowany użytkownik (null, gdy brak sesji).
  User? get currentUser;

  /// Czy e-mail bieżącego użytkownika został potwierdzony.
  bool isEmailConfirmed();
}
