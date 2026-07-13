import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/daily_stock.dart';
import '../../../../data/repositories/daily_stock_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';
import '../view_models/daily_stock_view_model.dart';

class DailyStockView extends StatelessWidget {
  const DailyStockView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => DailyStockViewModel(
        dailyStockRepository: context.read<DailyStockRepository>(),
      )..init(),
      child: const _DailyStockScreen(),
    );
  }
}

class _DailyStockScreen extends StatelessWidget {
  const _DailyStockScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final repo = context.watch<DailyStockRepository>();
    final viewModel = context.watch<DailyStockViewModel>();
    final dateLabel = formatIndonesianDate(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dailyStockTitle),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/inventory/stock'),
            icon: const Icon(Icons.bar_chart, size: 18),
            label: Text(l10n.stockValuationLink),
          ),
        ],
      ),
      floatingActionButton: !repo.loading && !repo.hasStocks
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/inventory/new'),
              icon: const Icon(Icons.add),
              label: Text(l10n.openStock),
            )
          : (!repo.loading && repo.isOpen
              ? FloatingActionButton.extended(
                  onPressed: viewModel.closing ? null : viewModel.closeDay,
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                  icon: viewModel.closing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.logout),
                  label: Text(l10n.closeToday),
                )
              : null),
      body: repo.loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(dateLabel, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  if (!repo.hasStocks)
                    _EmptyDailyStock(l10n: l10n, theme: theme)
                  else if (repo.isOpen)
                    _StockTable(
                      l10n: l10n,
                      theme: theme,
                      stocks: repo.stocks,
                      closed: false,
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(l10n.dailyStockClosedBanner,
                                style: theme.textTheme.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StockTable(
                      l10n: l10n,
                      theme: theme,
                      stocks: repo.stocks,
                      closed: true,
                    ),
                  ],
                  if (viewModel.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      viewModel.errorMessage!,
                      style: theme.textTheme.bodyMedium!
                          .copyWith(color: theme.colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _EmptyDailyStock extends StatelessWidget {
  const _EmptyDailyStock({required this.l10n, required this.theme});

  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.inventory_outlined,
              size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(l10n.dailyStockEmptyTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(l10n.dailyStockEmptyMessage,
              style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _StockTable extends StatelessWidget {
  const _StockTable({
    required this.l10n,
    required this.theme,
    required this.stocks,
    required this.closed,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final List<DailyStockItem> stocks;
  final bool closed;

  @override
  Widget build(BuildContext context) {
    final totalOpening = stocks.fold<int>(0, (sum, s) => sum + s.openingQty);
    final totalSold = stocks.fold<int>(0, (sum, s) => sum + s.soldQty);
    final totalClosing =
        stocks.fold<int>(0, (sum, s) => sum + (s.closingQty ?? 0));

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: DataTable(
        columnSpacing: 16,
        columns: [
          DataColumn(label: Text(l10n.columnMenu)),
          DataColumn(label: Text(l10n.columnOpen), numeric: true),
          DataColumn(label: Text(l10n.columnSold), numeric: true),
          DataColumn(
              label: Text(closed ? l10n.columnClosing : l10n.columnRemaining),
              numeric: true),
        ],
        rows: [
          for (final s in stocks)
            DataRow(cells: [
              DataCell(Text(s.productName)),
              DataCell(Text('${s.openingQty}')),
              DataCell(Text('${s.soldQty}')),
              DataCell(Text('${closed ? (s.closingQty ?? 0) : s.remainingQty}')),
            ]),
          DataRow(cells: [
            DataCell(
                Text(l10n.columnTotal, style: theme.textTheme.titleSmall)),
            DataCell(Text('$totalOpening')),
            DataCell(Text('$totalSold')),
            DataCell(Text('$totalClosing')),
          ]),
        ],
      ),
    );
  }
}
