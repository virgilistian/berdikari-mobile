import 'package:berdikari_mobile/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  group('AuthRepository.restoreSession', () {
    test('no persisted token -> unauthenticated', () async {
      final repo = fakeAuthRepository(user: sampleUser());

      await repo.restoreSession();

      expect(repo.status, AuthStatus.unauthenticated);
      expect(repo.user, isNull);
    });

    test('valid token -> authenticated with hydrated permissions', () async {
      final repo = fakeAuthRepository(user: sampleUser(), token: 'persisted');

      await repo.restoreSession();

      expect(repo.status, AuthStatus.authenticated);
      expect(repo.hasPermission('finance.view'), isTrue);
      expect(repo.hasPermission('user.manage'), isFalse);
      expect(repo.hasAnyPermission(['user.manage', 'pos.view']), isTrue);
      expect(repo.hasRole('cashier'), isTrue);
    });

    test('rejected token is cleared -> unauthenticated', () async {
      final storage = InMemoryTokenStorage('expired');
      final repo = AuthRepository(
        service: FakeAuthService(user: null), // me() throws 401
        tokenStorage: storage,
      );

      await repo.restoreSession();

      expect(repo.status, AuthStatus.unauthenticated);
      expect(storage.token, isNull);
    });
  });

  group('AuthRepository login/logout', () {
    test('login persists token and authenticates', () async {
      final storage = InMemoryTokenStorage();
      final repo = AuthRepository(
        service: FakeAuthService(user: sampleUser(), token: 'fresh-token'),
        tokenStorage: storage,
      );

      await repo.login(email: 'sari@berdikari.id', password: 'rahasia');

      expect(repo.isAuthenticated, isTrue);
      expect(storage.token, 'fresh-token');
      expect(repo.user?.name, 'Ibu Sari');
    });

    test('logout revokes server-side and clears local session', () async {
      final storage = InMemoryTokenStorage('persisted');
      final service = FakeAuthService(user: sampleUser());
      final repo = AuthRepository(service: service, tokenStorage: storage);
      await repo.restoreSession();

      await repo.logout();

      expect(service.logoutCalled, isTrue);
      expect(repo.status, AuthStatus.unauthenticated);
      expect(storage.token, isNull);
      expect(repo.hasPermission('finance.view'), isFalse);
    });

    test('deny-by-default: no user -> every permission check is false', () {
      final repo = fakeAuthRepository();

      expect(repo.hasPermission('finance.view'), isFalse);
      expect(repo.hasAnyPermission(['pos.view', 'pos.open']), isFalse);
      expect(repo.hasRole('business-owner'), isFalse);
    });
  });
}
