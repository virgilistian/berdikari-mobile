import 'package:flutter/material.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../l10n/generated/app_localizations.dart';

/// One navigation destination. Mirrors `NavItem` in berdikari-web
/// `app/config/nav.ts` (§9f of the Project DNA): permissions drive
/// visibility — an item is visible if the user holds AT LEAST ONE of its
/// permissions; an empty list means "always visible when authenticated".
class NavItem {
  const NavItem({
    required this.route,
    required this.icon,
    required this.label,
    required this.permissions,
  });

  final String route;
  final IconData icon;
  final String Function(AppLocalizations) label;
  final List<String> permissions;

  bool visibleFor(AuthRepository auth) =>
      permissions.isEmpty || auth.hasAnyPermission(permissions);
}

/// Static nav registry — ported 1:1 from the web app. When adding a new
/// page, add its entry here; never hardcode nav in a widget.
///
/// Note: unlike the web sidebar, `Pengaturan` here is the ACCOUNT hub
/// (profile / password / logout) which every authenticated user needs, so
/// its permission list is empty. Admin-only destinations (Pengguna,
/// Peran & Akses) keep their own permissions.
final List<NavItem> navRegistry = [
  NavItem(
    route: '/',
    icon: Icons.space_dashboard_outlined,
    label: (l) => l.navHome,
    permissions: const [],
  ),
  NavItem(
    route: '/pos',
    icon: Icons.shopping_cart_outlined,
    label: (l) => l.navPos,
    permissions: const ['pos.view', 'pos.open'],
  ),
  NavItem(
    route: '/pos/shift',
    icon: Icons.schedule_outlined,
    label: (l) => l.navShift,
    permissions: const ['pos.open', 'pos.close'],
  ),
  NavItem(
    route: '/finance',
    icon: Icons.account_balance_wallet_outlined,
    label: (l) => l.navFinance,
    permissions: const ['finance.view'],
  ),
  NavItem(
    route: '/catalog',
    icon: Icons.sell_outlined,
    label: (l) => l.navCatalog,
    permissions: const ['catalog.view'],
  ),
  NavItem(
    route: '/inventory',
    icon: Icons.inventory_2_outlined,
    label: (l) => l.navInventory,
    permissions: const ['inventory.view'],
  ),
  NavItem(
    route: '/reports',
    icon: Icons.bar_chart,
    label: (l) => l.navReports,
    permissions: const ['report.view'],
  ),
  NavItem(
    route: '/employees',
    icon: Icons.people_alt_outlined,
    label: (l) => l.navEmployees,
    permissions: const ['employee.view'],
  ),
  NavItem(
    route: '/employees/attendance',
    icon: Icons.event_available_outlined,
    label: (l) => l.navAttendance,
    permissions: const ['attendance.create', 'attendance.view'],
  ),
  NavItem(
    route: '/settings',
    icon: Icons.settings_outlined,
    label: (l) => l.navSettings,
    permissions: const [],
  ),
  NavItem(
    route: '/users',
    icon: Icons.manage_accounts_outlined,
    label: (l) => l.navUsers,
    permissions: const ['user.manage'],
  ),
  NavItem(
    route: '/roles',
    icon: Icons.verified_user_outlined,
    label: (l) => l.navRoles,
    permissions: const ['role.assign'],
  ),
];

/// The 4 highest-frequency destinations pinned to the bottom nav —
/// same set as the web's `mobileNavItems`. Everything else lives in
/// the "Lainnya" sheet.
const List<String> mobileNavRoutes = ['/', '/finance', '/pos', '/inventory'];

List<NavItem> bottomNavItems(AuthRepository auth) => mobileNavRoutes
    .map((route) => navRegistry.firstWhere((item) => item.route == route))
    .where((item) => item.visibleFor(auth))
    .toList();

List<NavItem> moreNavItems(AuthRepository auth) => navRegistry
    .where((item) => !mobileNavRoutes.contains(item.route))
    .where((item) => item.visibleFor(auth))
    .toList();

/// Route -> required permissions, for the router's deny-by-default guard.
/// Non-registry routes (reached from within screens, not the nav) are
/// listed explicitly.
final Map<String, List<String>> routePermissions = {
  for (final item in navRegistry) item.route: item.permissions,
  '/pos/orders': const ['pos.view', 'pos.open'],
  '/inventory/new': const ['inventory.create'],
  '/inventory/stock': const ['inventory.view'],
  '/finance/new': const ['finance.create'],
};
