import 'package:berdikari_mobile/ui/core/navigation/nav_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes.dart';

void main() {
  group('nav registry visibility', () {
    test('cashier sees Kasir + Beranda in bottom nav, not Keuangan', () async {
      final repo = fakeAuthRepository(
        user: sampleUser(permissions: ['pos.view', 'pos.open', 'pos.close']),
        token: 't',
      );
      await repo.restoreSession();

      final routes = bottomNavItems(repo).map((i) => i.route).toList();

      expect(routes, contains('/'));
      expect(routes, contains('/pos'));
      expect(routes, isNot(contains('/finance')));
      expect(routes, isNot(contains('/inventory')));
    });

    test('viewer-without-permissions gets only always-visible items',
        () async {
      final repo = fakeAuthRepository(
        user: sampleUser(permissions: [], roles: ['viewer']),
        token: 't',
      );
      await repo.restoreSession();

      expect(bottomNavItems(repo).map((i) => i.route), ['/']);

      final moreRoutes = moreNavItems(repo).map((i) => i.route).toList();
      expect(moreRoutes, ['/settings']); // account hub is always visible
    });

    test('admin permissions surface admin destinations in Lainnya', () async {
      final repo = fakeAuthRepository(
        user: sampleUser(
          permissions: ['user.manage', 'role.assign'],
          roles: ['business-owner'],
        ),
        token: 't',
      );
      await repo.restoreSession();

      final moreRoutes = moreNavItems(repo).map((i) => i.route).toList();
      expect(moreRoutes, containsAll(['/users', '/roles', '/settings']));
    });
  });

  group('routePermissions guard map', () {
    test('mirrors the registry', () {
      expect(routePermissions['/users'], ['user.manage']);
      expect(routePermissions['/finance'], ['finance.view']);
      expect(routePermissions['/'], isEmpty);
      expect(routePermissions['/settings'], isEmpty);
    });
  });
}
