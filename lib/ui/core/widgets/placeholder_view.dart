import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Stand-in for destinations that exist in the nav registry but whose
/// feature phase has not shipped yet. Replaced phase by phase.
class PlaceholderView extends StatelessWidget {
  const PlaceholderView({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.comingSoon,
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}
