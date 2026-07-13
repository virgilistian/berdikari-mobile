import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Placeholder dashboard — real KPIs land in Phase 4.
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final user = context.watch<AuthRepository>().user;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.storefront_outlined,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.homeGreetingUser(user?.name ?? ''),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(l10n.homeSubtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
