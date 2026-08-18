import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../core/errors/app_exceptions.dart';
import '../models/user.dart';
import 'interfaces/i_auth_service.dart';

/// Implementacja IAuthService na Supabase Auth (Część C2).
/// Używa Supabase.instance.client.auth (API v2).
/// service_role NIGDY nie występuje w aplikacji — tylko anon klucz z --dart-define.
class SupabaseAuthService implements IAuthService {
  SupabaseAuthService();

  supabase.GoTrueClient get _auth => supabase.Supabase.instance.client.auth;

  @override
  User? get currentUser {
    final authUser = _auth.currentUser;
    if (authUser == null) return null;
    return User(
      id: authUser.id,
      email: authUser.email ?? '',
      displayName: authUser.userMetadata?['display_name'] as String?,
    );
  }

  @override
  bool isEmailConfirmed() => _auth.currentUser?.emailConfirmedAt != null;

  /// Tłumaczy wyjątek z pakietu supabase_flutter na aplikacyjny AuthException
  /// z czytelnym komunikatem PL. Bez tego błąd trafiałby do generycznego
  /// catch (_) w AuthScreen ("Nieznany błąd logowania").
  Never _mapSupabaseAuthError(Object error) {
    if (error is supabase.AuthException) {
      final msg = error.message.toLowerCase();
      final code = error.code?.toLowerCase() ?? '';
      final status = error.statusCode ?? '';
      if (code.contains('invalid_credentials') ||
          msg.contains('invalid login credentials') ||
          msg.contains('invalid_credentials')) {
        throw AuthException('Nieprawidłowy e-mail lub hasło.');
      }
      if (code.contains('email_not_confirmed') ||
          msg.contains('not confirmed') ||
          msg.contains('email not confirmed') ||
          status == '422') {
        throw AuthException('Potwierdź e-mail przed logowaniem.');
      }
      if (status == '429' || msg.contains('rate limit') || msg.contains('too many')) {
        throw AuthException('Zbyt wiele prób. Spróbuj później.');
      }
      throw AuthException('Błąd logowania: ${error.message}');
    }
    throw AuthException('Błąd logowania: $error');
  }

  @override
  Future<AuthResult> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signUp(email: email, password: password);
      final authUser = response.user;
      if (authUser == null) {
        throw AuthException('Brak odpowiedzi rejestracji od serwera.');
      }
      return AuthResult(
        user: User(
          id: authUser.id,
          email: authUser.email ?? email,
          displayName: authUser.userMetadata?['display_name'] as String?,
        ),
        isEmailConfirmed: authUser.emailConfirmedAt != null,
      );
    } catch (e) {
      _mapSupabaseAuthError(e);
    }
  }

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      final authUser = response.user;
      if (authUser == null) {
        throw AuthException('Nieprawidłowy e-mail lub hasło.');
      }
      return AuthResult(
        user: User(
          id: authUser.id,
          email: authUser.email ?? email,
          displayName: authUser.userMetadata?['display_name'] as String?,
        ),
        isEmailConfirmed: authUser.emailConfirmedAt != null,
      );
    } catch (e) {
      _mapSupabaseAuthError(e);
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Usuwanie konta przez RPC delete_my_account() (migracja K9/B2).
  /// SECURITY DEFINER po stronie bazy: kasuje rate_limits + auth.users,
  /// a ON DELETE CASCADE usuwa profiles/sessions/messages/reports.
  /// Po powodzeniu wywołuje signOut (sesja musi zniknąć lokalnie).
  @override
  Future<void> deleteAccount() async {
    try {
      await supabase.Supabase.instance.client.rpc('delete_my_account');
      await _auth.signOut();
    } on supabase.AuthException catch (e) {
      throw AuthException('Błąd usuwania konta: ${e.message}');
    } catch (e) {
      throw AuthException('Błąd usuwania konta: $e');
    }
  }
}
