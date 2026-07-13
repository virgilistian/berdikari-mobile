import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/stock.dart';
import '../../../../data/repositories/stock_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';
import '../view_models/stock_action_view_model.dart';
import '../widgets/movement_history_sheet.dart';
import '../widgets/stock_action_sheet.dart';

class StockValuationView extends StatelessWidget {
  const StockValuationView({super.key});

  @override
  Widget build(BuildContext context) {
    // Re-provides the app-level StockRepository singleton (not a new
    // instance) so `..fetchStock()` runs once when this screen mounts,
    // synchronously flipping `loading` before the first frame paints.
    return ChangeNotifierProvider<StockRepository>(
      create: (context) => context.read<StockRepository>()..fetchStock(),
      child: const _StockValuationScreen(),
    );
  }
}

class _StockValuationScreen extends StatelessWidget {
  const _StockValuationScreen();

  Future<void> _openAction(
    BuildContext context,
    StockActionType type,
    StockRow row,
  ) async {
    final refreshed = await showStockActionSheet(context, type: type, row: row);
    if (refreshed && context.mounted) {
      context.read<StockRepository>().fetchStock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final repo = context.watch<StockRepository>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.stockValuationTitle),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/inventory'),
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text(l10n.dailyStockLink),
          ),
        ],
      ),
      body: repo.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: repo.fetchStock,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (repo.error != null)
                    Text(repo.error!,
                        style: theme.textTheme.bodyMedium!
                            .copyWith(color: theme.colorScheme.error)),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.6,
                    children: [
                      _KpiCard(
                        label: l10n.stockValueLabel,
                        value: formatRupiah(repo.summary?.stockValue ?? 0),
                      ),
                      _KpiCard(
                        label: l10n.retailValueLabel,
                        value: formatRupiah(repo.summary?.retailValue ?? 0),
                      ),
                      _KpiCard(
                        label: l10n.totalProductsLabel,
                        value: '${repo.summary?.totalProducts ?? 0}',
                      ),
                      _KpiCard(
                        label: l10n.lowStockLabel,
                        value: '${repo.summary?.lowStockCount ?? 0}',
                        warn: (repo.summary?.lowStockCount ?? 0) > 0,
                      ),
                    ],
                  ),
                  if (repo.lowStockRows.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
                        border: Border.all(
                            color: theme.colorScheme.tertiary
                                .withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_outlined,
                                  color: theme.colorScheme.tertiary, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  l10n.lowStockAlert(repo.lowStockRows.length),
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          for (final row in repo.lowStockRows)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(row.productName)),
                                  Text(
                                    l10n.remainingOfMin(
                                        row.quantity, row.minStock),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (repo.rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 48, color: theme.colorScheme.primary),
                          const SizedBox(height: 12),
                          Text(l10n.stockEmptyTitle,
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(l10n.stockEmptyMessage,
                              style: theme.textTheme.bodySmall,
                              textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  else
                    for (final row in repo.rows)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => showMovementHistorySheet(
                            context,
                            productId: row.productId,
                            productName: row.productName,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(row.productName,
                                                style: theme
                                                    .textTheme.titleSmall),
                                          ),
                                          if (row.isLow)
                                            Chip(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              backgroundColor: theme
                                                  .colorScheme.tertiary
                                                  .withValues(alpha: 0.15),
                                              label: Text(l10n.lowStockBadge,
                                                  style: TextStyle(
                                                      color: theme.colorScheme
                                                          .tertiary)),
                                            ),
                                        ],
                                      ),
                                      Text(
                                        '${formatRupiah(row.purchasePrice)} · ${formatRupiah(row.stockValue)}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${row.quantity}',
                                        style: theme.textTheme.titleMedium),
                                    Text(l10n.minStockShort(row.minStock),
                                        style: theme.textTheme.bodySmall),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      height: 32,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          minimumSize: Size.zero,
                                        ),
                                        onPressed: () => _openAction(context,
                                            StockActionType.receive, row),
                                        child: Text(l10n.receiveAction,
                                            style: theme.textTheme.bodySmall),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      height: 32,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          minimumSize: Size.zero,
                                        ),
                                        onPressed: () => _openAction(context,
                                            StockActionType.adjust, row),
                                        child: Text(l10n.adjustAction,
                                            style: theme.textTheme.bodySmall),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value, this.warn = false});

  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge!.copyWith(
                color: warn ? theme.colorScheme.tertiary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
