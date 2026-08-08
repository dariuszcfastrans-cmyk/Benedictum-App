/// Model zalogowanego użytkownika Benedictum.
class User {
  const User({
    required this.id,
    required this.email,
    this.displayName,
  });

  final String id;
  final String email;
  final String? displayName;
}

/// Wynik operacji autoryzacji (signUp / signIn).
class AuthResult {
  const AuthResult({
    required this.user,
    required this.isEmailConfirmed,
  });

  final User user;

  /// Czy adres e-mail został potwierdzony (np. linkiem weryfikacyjnym).
  final bool isEmailConfirmed;
}
