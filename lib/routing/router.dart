import 'package:go_router/go_router.dart';

import '../ui/features/home/views/home_view.dart';

/// App routes. Phase 1 adds the auth redirect guard and the
/// permission-driven navigation shell (see docs/16 in the berdikari repo).
abstract final class AppRoutes {
  static const home = '/';
}

GoRouter createRouter() => GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const HomeView(),
        ),
      ],
    );
