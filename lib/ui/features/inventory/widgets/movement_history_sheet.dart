import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/stock.dart';
import '../../../../data/repositories/stock_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// DNA §5d step 3: tapping a stock row shows its movement history.
Future<void> showMovementHistorySheet(
  BuildContext context, {
  required String productId,
  required String productName,
}) {
  final repo = context.read<StockRepository>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MovementHistorySheet(
      productId: productId,
      productName: productName,
      future: repo.fetchMovements(productId),
    ),
  );
}

class _MovementHistorySheet extends StatelessWidget {
  const _MovementHistorySheet({
    required this.productId,
    required this.productName,
    required this.future,
  });

  final String productId;
  final String productName;
  final Future<List<StockMovement>> future;

  String _typeLabel(AppLocalizations l10n, String type) => switch (type) {
        'in' => l10n.movementIn,
        'out' => l10n.movementOut,
        _ => l10n.movementAdjustment,
      };

  IconData _typeIcon(String type) => switch (type) {
        'in' => Icons.arrow_downward,
        'out' => Icons.arrow_upward,
        _ => Icons.tune,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.movementHistoryTitle, style: theme.textTheme.titleMedium),
            Text(productName, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: FutureBuilder<List<StockMovement>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final movements = snapshot.data ?? const [];
                  if (movements.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(l10n.movementEmpty,
                            style: theme.textTheme.bodyMedium),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: movements.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final movement = movements[index];
                      final isOut = movement.type == 'out';
                      return ListTile(
                        leading: Icon(_typeIcon(movement.type)),
                        title: Text(_typeLabel(l10n, movement.type)),
                        subtitle: movement.reason != null
                            ? Text(movement.reason!)
                            : null,
                        trailing: Text(
                          '${isOut ? '-' : '+'}${movement.quantity}',
                          style: theme.textTheme.titleSmall!.copyWith(
                            color: isOut
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
