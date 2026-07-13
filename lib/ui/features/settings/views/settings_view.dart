import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/cart_repository.dart';
import '../../../../data/repositories/shift_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Account hub: profile, password, logout. Mirrors the web's `/settings`.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthRepository>();
    final cart = context.read<CartRepository>();
    final shift = context.read<ShiftRepository>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.logoutConfirmTitle),
        content: Text(l10n.logoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // The next user starts clean: no leftover cart or shift state.
      cart.clear();
      shift.reset();
      await auth.logout();
      // Router redirect takes over: unauthenticated -> /login.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final user = context.watch<AuthRepository>().user;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          if (user != null)
            ListTile(
              minTileHeight: 56,
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                child: Text(user.name.isNotEmpty
                    ? user.name[0].toUpperCase()
                    : '?'),
              ),
              title: Text(user.name),
              subtitle: Text(user.email),
            ),
          const Divider(),
          ListTile(
            minTileHeight: 48,
            leading: const Icon(Icons.person_outline),
            title: Text(l10n.profileTitle),
            subtitle: Text(l10n.profileSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/profile'),
          ),
          ListTile(
            minTileHeight: 48,
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.changePasswordTitle),
            subtitle: Text(l10n.changePasswordSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/password'),
          ),
          const Divider(),
          ListTile(
            minTileHeight: 48,
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text(
              l10n.logout,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }
}
