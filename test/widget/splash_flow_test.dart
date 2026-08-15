import 'package:flutter_test/flutter_test.dart';

import 'package:benedictum_mobile/services/mocks/mock_auth_service.dart';

void main() {
  test('Splash UX: signIn tworzy sesję (currentUser != null)', () async {
    final auth = MockAuthService();
    expect(auth.currentUser, isNull);
    await auth.signIn(email: 'a@b.com', password: 'secret');
    expect(auth.currentUser, isNotNull);
    expect(auth.currentUser!.email, 'a@b.com');
  });

  test('Splash UX: signOut czyści sesję (currentUser == null)', () async {
    final auth = MockAuthService();
    await auth.signIn(email: 'a@b.com', password: 'secret');
    expect(auth.currentUser, isNotNull);

    await auth.signOut();
    expect(auth.currentUser, isNull);
  });

  test('Splash UX: brak sesji po skonstruowaniu', () {
    final auth = MockAuthService();
    expect(auth.currentUser, isNull);
  });
}
