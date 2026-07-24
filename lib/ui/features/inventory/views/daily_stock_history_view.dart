import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/daily_stock.dart';
import '../../../../data/repositories/daily_stock_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';

String dailyStockStatusLabel(AppLocalizations l10n, String status) =>
    switch (status) {
      'draft' => l10n.dailyStockStatusDraft,
      'open' => l10n.dailyStockStatusOpen,
      _ => l10n.dailyStockStatusClosed,
    };

Color dailyStockStatusColor(ThemeData theme, String status) => switch (status) {
      'draft' => theme.colorScheme.warning,
      'open' => theme.colorScheme.success,
      _ => theme.colorScheme.onSurfaceVariant,
    };

/// Per-date stock opname history — mirrors berdikari-web `pages/inventory/index.vue`.
class DailyStockHistoryView extends StatefulWidget {
  const DailyStockHistoryView({super.key});

  @override
  State<DailyStockHistoryView> createState() => _DailyStockHistoryViewState();
}

class _DailyStockHistoryViewState extends State<DailyStockHistoryView> {
  @override
  void initState() {
    super.initState();
    context.read<DailyStockRepository>().fetchHistory();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final repo = context.watch<DailyStockRepository>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dailyStockHistoryTitle),
        leading: BackButton(onPressed: () => context.go('/inventory')),
        actions: [
          IconButton(
            tooltip: l10n.dailyStockAddButton,
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/inventory/new'),
          ),
        ],
      ),
      body: repo.historyLoading
          ? const Center(child: CircularProgressIndicator())
          : repo.history.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_outlined,
                            size: 48, color: theme.colorScheme.primary),
                        const SizedBox(height: 12),
                        Text(l10n.dailyStockHistoryEmptyTitle,
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(l10n.dailyStockHistoryEmptyMessage,
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: repo.fetchHistory,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: repo.history.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _HistoryRow(row: repo.history[index]),
                  ),
                ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.row});

  final DailyStockHistoryRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/inventory/history/${row.date}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(row.date, style: theme.textTheme.titleSmall),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: dailyStockStatusColor(theme, row.status)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            dailyStockStatusLabel(l10n, row.status),
                            style: theme.textTheme.labelSmall!.copyWith(
                                color: dailyStockStatusColor(theme, row.status)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${row.totalMenuItems} menu · ${l10n.columnOpen} ${row.totalOpeningQty} · ${l10n.columnClosing} ${row.totalClosingQty}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
