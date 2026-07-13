import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';

/// Placeholder shell screen. Replaced by the real dashboard in Phase 4;
/// Phase 1 puts the login flow in front of it.
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

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
              Text(l10n.homeGreeting, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(l10n.homeSubtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
