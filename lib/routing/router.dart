import 'package:go_router/go_router.dart';

import '../data/repositories/auth_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../ui/core/navigation/app_shell.dart';
import '../ui/core/navigation/nav_registry.dart';
import '../ui/core/widgets/placeholder_view.dart';
import '../ui/core/widgets/splash_view.dart';
import '../ui/features/auth/views/login_view.dart';
import '../ui/features/forbidden/views/forbidden_view.dart';
import '../ui/features/home/views/home_view.dart';
import '../ui/features/settings/views/password_view.dart';
import '../ui/features/settings/views/profile_view.dart';
import '../ui/features/settings/views/settings_view.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const forbidden = '/403';
  static const home = '/';
  static const settings = '/settings';
  static const settingsProfile = '/settings/profile';
  static const settingsPassword = '/settings/password';
}

/// Registry routes whose feature phase has shipped — everything else in the
/// nav registry renders a "Segera hadir" placeholder until its phase lands.
const _implementedRoutes = {
  AppRoutes.home,
  AppRoutes.settings,
};

/// Deny-by-default guard (§9 of the Project DNA):
/// - session restoring -> splash
/// - unauthenticated  -> /login
/// - authenticated on /login or /splash -> /
/// - route requires permissions the user lacks -> /403
String? _redirect(AuthRepository auth, GoRouterState state) {
  final path = state.uri.path;

  if (auth.status == AuthStatus.unknown) {
    return path == AppRoutes.splash ? null : AppRoutes.splash;
  }
  if (!auth.isAuthenticated) {
    return path == AppRoutes.login ? null : AppRoutes.login;
  }
  if (path == AppRoutes.login || path == AppRoutes.splash) {
    return AppRoutes.home;
  }

  final required = routePermissions[path];
  if (required != null &&
      required.isNotEmpty &&
      !auth.hasAnyPermission(required)) {
    return AppRoutes.forbidden;
  }
  return null;
}

GoRouter createRouter(AuthRepository auth) => GoRouter(
      initialLocation: AppRoutes.splash,
      refreshListenable: auth,
      redirect: (context, state) => _redirect(auth, state),
      routes: [
        // Outside the shell: no bottom nav.
        GoRoute(
          path: AppRoutes.splash,
          builder: (context, state) => const SplashView(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const LoginView(),
        ),
        GoRoute(
          path: AppRoutes.forbidden,
          builder: (context, state) => const ForbiddenView(),
        ),

        // Authenticated shell with the permission-driven bottom nav.
        ShellRoute(
          builder: (context, state, child) =>
              AppShell(currentPath: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomeView(),
            ),
            GoRoute(
              path: AppRoutes.settings,
              builder: (context, state) => const SettingsView(),
            ),
            GoRoute(
              path: AppRoutes.settingsProfile,
              builder: (context, state) => const ProfileView(),
            ),
            GoRoute(
              path: AppRoutes.settingsPassword,
              builder: (context, state) => const PasswordView(),
            ),
            // Placeholders for registry destinations from later phases.
            for (final item in navRegistry
                .where((item) => !_implementedRoutes.contains(item.route)))
              GoRoute(
                path: item.route,
                builder: (context, state) => PlaceholderView(
                  title: item.label(AppLocalizations.of(context)!),
                ),
              ),
          ],
        ),
      ],
    );
