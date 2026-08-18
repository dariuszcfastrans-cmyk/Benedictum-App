import 'dart:math';

import '../../models/user.dart';
import '../interfaces/i_auth_service.dart';

/// Mock usługi autoryzacji — Część C1.
/// UWAGA: 100% lokalny mock, ZERO sieci. Przyjmuje dowolne dane.
/// Do podpięcia prawdziwego Supabase Auth w części C2.
class MockAuthService implements IAuthService {
  MockAuthService();

  final Random _random = Random();
  User? _currentUser;
  bool _emailConfirmed = false;

  @override
  User? get currentUser => _currentUser;

  @override
  bool isEmailConfirmed() => _emailConfirmed;

  @override
  Future<AuthResult> signUp({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _currentUser = User(
      id: 'mock_user_${_random.nextInt(100000)}',
      email: email,
    );
    _emailConfirmed = false;
    return AuthResult(user: _currentUser!, isEmailConfirmed: false);
  }

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _currentUser = User(
      id: 'mock_user_${_random.nextInt(100000)}',
      email: email,
    );
    _emailConfirmed = true;
    return AuthResult(user: _currentUser!, isEmailConfirmed: true);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _emailConfirmed = false;
  }

  @override
  Future<void> deleteAccount() async {
    await signOut();
  }
}
