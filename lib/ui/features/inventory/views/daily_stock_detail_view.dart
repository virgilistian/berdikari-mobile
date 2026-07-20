import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/daily_stock.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/daily_stock_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import 'daily_stock_history_view.dart' show dailyStockStatusColor;

/// Detail for one stock-opname date — mirrors berdikari-web
/// `pages/inventory/[date].vue`: draft (not live yet, editable/deletable),
/// open (live, auto-closes via shift close), or closed (EOD recap).
class DailyStockDetailView extends StatefulWidget {
  const DailyStockDetailView({super.key, required this.date});

  final String date;

  @override
  State<DailyStockDetailView> createState() => _DailyStockDetailViewState();
}

class _DailyStockDetailViewState extends State<DailyStockDetailView> {
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    context.read<DailyStockRepository>().fetchDayDetail(widget.date);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.dailyStockDeleteDraftConfirmTitle),
        content: Text(l10n.dailyStockDeleteDraftConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.dailyStockDeleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    setState(() => _deleting = true);
    try {
      await context.read<DailyStockRepository>().deleteDay(widget.date);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.dailyStockDeleted)),
        );
        context.go('/inventory/history');
      }
    } catch (_) {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final auth = context.watch<AuthRepository>();
    final repo = context.watch<DailyStockRepository>();
    final items = repo.dayDetail;
    final canManage = auth.hasPermission('inventory.create');

    final isDraft = items.any((s) => s.isDraft);
    final isOpen = items.any((s) => s.isOpen);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dailyStockDetailTitle),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: repo.dayDetailLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? Center(
                  child: Text(l10n.dailyStockNoDataForDate,
                      style: theme.textTheme.bodyMedium),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isDraft) ...[
                        _Banner(
                          icon: Icons.schedule,
                          color: dailyStockStatusColor(theme, 'draft'),
                          text: l10n.dailyStockDraftBanner,
                        ),
                        const SizedBox(height: 12),
                        _StockTable(items: items, mode: _TableMode.draft),
                        if (canManage) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => context
                                      .push('/inventory/new?date=${widget.date}'),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: Text(l10n.dailyStockEditAction),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _deleting
                                      ? null
                                      : () => _confirmDelete(context),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: theme.colorScheme.error,
                                    side: BorderSide(
                                        color: theme.colorScheme.error
                                            .withValues(alpha: 0.4)),
                                  ),
                                  icon: _deleting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : const Icon(Icons.delete_outline),
                                  label: Text(l10n.dailyStockDeleteAction),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ] else if (isOpen) ...[
                        _StockTable(items: items, mode: _TableMode.open),
                        const SizedBox(height: 8),
                        Text(l10n.dailyStockAutoCloseNote,
                            style: theme.textTheme.bodySmall),
                      ] else ...[
                        _Banner(
                          icon: Icons.check_circle_outline,
                          color: theme.colorScheme.success,
                          text: l10n.dailyStockClosedBanner,
                        ),
                        const SizedBox(height: 12),
                        _StockTable(items: items, mode: _TableMode.closed),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: theme.textTheme.bodyMedium!.copyWith(color: color))),
        ],
      ),
    );
  }
}

enum _TableMode { draft, open, closed }

class _StockTable extends StatelessWidget {
  const _StockTable({required this.items, required this.mode});

  final List<DailyStockItem> items;
  final _TableMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final totalOpening = items.fold<int>(0, (s, i) => s + i.openingQty);
    final totalSold = items.fold<int>(0, (s, i) => s + i.soldQty);
    final totalClosing =
        items.fold<int>(0, (s, i) => s + (mode == _TableMode.closed ? (i.closingQty ?? 0) : i.remainingQty));

    final columns = <DataColumn>[
      DataColumn(label: Text(l10n.columnMenu)),
      DataColumn(label: Text(l10n.columnOpen), numeric: true),
      if (mode != _TableMode.draft) ...[
        DataColumn(label: Text(l10n.columnSold), numeric: true),
        DataColumn(
            label: Text(mode == _TableMode.closed
                ? l10n.columnClosing
                : l10n.columnRemaining),
            numeric: true),
      ],
    ];

    List<DataCell> rowCells(DailyStockItem item) {
      final cells = <DataCell>[
        DataCell(Text(item.productName)),
        DataCell(Text('${item.openingQty}')),
      ];
      if (mode != _TableMode.draft) {
        cells.add(DataCell(Text('${item.soldQty}')));
        cells.add(DataCell(Text(
            '${mode == _TableMode.closed ? (item.closingQty ?? 0) : item.remainingQty}')));
      }
      return cells;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: DataTable(
        columnSpacing: 16,
        columns: columns,
        rows: [
          for (final item in items) DataRow(cells: rowCells(item)),
          if (mode != _TableMode.draft)
            DataRow(cells: [
              DataCell(Text(l10n.columnTotal, style: theme.textTheme.titleSmall)),
              DataCell(Text('$totalOpening')),
              DataCell(Text('$totalSold')),
              DataCell(Text('$totalClosing')),
            ]),
        ],
      ),
    );
  }
}
