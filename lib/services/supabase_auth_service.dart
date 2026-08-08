import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthException, User;

import '../core/errors/app_exceptions.dart';
import '../models/user.dart';
import 'interfaces/i_auth_service.dart';

/// Implementacja IAuthService na Supabase Auth (Część C2).
/// Używa Supabase.instance.client.auth (API v2).
/// service_role NIGDY nie występuje w aplikacji — tylko anon klucz z --dart-define.
class SupabaseAuthService implements IAuthService {
  SupabaseAuthService();

  GoTrueClient get _auth => Supabase.instance.client.auth;

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

  @override
  Future<AuthResult> signUp({
    required String email,
    required String password,
  }) async {
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
  }

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
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
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
