import 'package:flutter_test/flutter_test.dart';

import 'package:benedictum_mobile/services/mocks/mock_auth_service.dart';

void main() {
  group('MockAuthService', () {
    test('signUp zwraca AuthResult z isEmailConfirmed=false i ustawia currentUser',
        () async {
      final service = MockAuthService();

      final result = await service.signUp(email: 'a@b.com', password: 'secret');

      expect(result.isEmailConfirmed, isFalse);
      expect(result.user.email, 'a@b.com');
      expect(service.currentUser, isNotNull);
      expect(service.currentUser!.email, 'a@b.com');
      expect(service.isEmailConfirmed(), isFalse);
    });

    test('signIn zwraca AuthResult z isEmailConfirmed=true', () async {
      final service = MockAuthService();

      final result = await service.signIn(email: 'a@b.com', password: 'secret');

      expect(result.isEmailConfirmed, isTrue);
      expect(result.user.email, 'a@b.com');
      expect(service.currentUser, isNotNull);
      expect(service.isEmailConfirmed(), isTrue);
    });

    test('signOut czyści currentUser i resetuje isEmailConfirmed', () async {
      final service = MockAuthService();
      await service.signIn(email: 'a@b.com', password: 'secret');
      expect(service.currentUser, isNotNull);

      await service.signOut();

      expect(service.currentUser, isNull);
      expect(service.isEmailConfirmed(), isFalse);
    });

    test('przed zalogowaniem currentUser jest null', () {
      final service = MockAuthService();
      expect(service.currentUser, isNull);
      expect(service.isEmailConfirmed(), isFalse);
    });
  });
}
