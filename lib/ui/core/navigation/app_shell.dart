import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'nav_registry.dart';

/// Authenticated navigation shell: permission-driven bottom nav
/// (max 4 pinned destinations + "Lainnya" sheet), ported from the web's
/// mobile layout. All touch targets are >= 44 dp.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.currentPath, required this.child});

  final String currentPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthRepository>();
    final l10n = AppLocalizations.of(context)!;
    final pinned = bottomNavItems(auth);
    final more = moreNavItems(auth);

    final pinnedIndex =
        pinned.indexWhere((item) => item.route == currentPath);
    final onMorePage = more.any((item) => item.route == currentPath);
    final moreIndex = pinned.length;

    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: pinnedIndex >= 0
            ? pinnedIndex
            : (onMorePage ? moreIndex : 0),
        onDestinationSelected: (index) {
          if (index < pinned.length) {
            context.go(pinned[index].route);
          } else {
            _showMoreSheet(context, more, l10n);
          }
        },
        destinations: [
          for (final item in pinned)
            NavigationDestination(
              icon: Icon(item.icon),
              label: item.label(l10n),
            ),
          NavigationDestination(
            icon: const Icon(Icons.more_horiz),
            label: l10n.navMore,
          ),
        ],
      ),
    );
  }

  void _showMoreSheet(
    BuildContext context,
    List<NavItem> items,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final item in items)
              ListTile(
                minTileHeight: 48,
                leading: Icon(item.icon),
                title: Text(item.label(l10n)),
                selected: item.route == currentPath,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.go(item.route);
                },
              ),
          ],
        ),
      ),
    );
  }
}
