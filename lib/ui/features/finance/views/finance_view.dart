import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/finance.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/finance_repository.dart';
import '../../../../data/services/api_client.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/filter/date_range_filter_sheet.dart';
import '../../../core/widgets/filter/filter_chips_bar.dart';
import '../../../core/widgets/filter/option_filter_sheet.dart';
import '../../../core/widgets/sync_status_indicator.dart';

String financePeriodLabel(AppLocalizations l10n, FinancePeriod period) =>
    switch (period) {
      FinancePeriod.all => l10n.financePeriodAll,
      FinancePeriod.today => l10n.financePeriodToday,
      FinancePeriod.week => l10n.financePeriodWeek,
      FinancePeriod.month => l10n.financePeriodMonth,
      FinancePeriod.year => l10n.financePeriodYear,
      FinancePeriod.custom => l10n.financePeriodCustom,
    };

/// Display-only date range for a period preset row's subtitle (GoPay-style
/// "1 Jul 2026 - 21 Jul 2026"). Never used for actual filtering — that stays
/// in [FinanceRepository]; `all`/`custom` have no fixed range to show.
String? _periodRangeSubtitle(FinancePeriod period) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final DateTime start;
  switch (period) {
    case FinancePeriod.all:
    case FinancePeriod.custom:
      return null;
    case FinancePeriod.today:
      return formatShortDate(today);
    case FinancePeriod.week:
      start = today.subtract(Duration(days: today.weekday - 1));
    case FinancePeriod.month:
      start = DateTime(today.year, today.month, 1);
    case FinancePeriod.year:
      start = DateTime(today.year, 1, 1);
  }
  return '${formatShortDate(start)} - ${formatShortDate(today)}';
}

/// `FinanceRepository` is an app-level singleton (provided once in
/// `app.dart`, shared with the dashboard) — unlike `StockRepository`'s
/// screen, this must NOT re-wrap it in a fresh `ChangeNotifierProvider`,
/// which would dispose the singleton the moment this screen unmounts.
class FinanceView extends StatefulWidget {
  const FinanceView({super.key});

  @override
  State<FinanceView> createState() => _FinanceViewState();
}

class _FinanceViewState extends State<FinanceView> {
  @override
  void initState() {
    super.initState();
    context.read<FinanceRepository>().fetchAll();
  }

  @override
  Widget build(BuildContext context) => const _FinanceScreen();
}

class _FinanceScreen extends StatelessWidget {
  const _FinanceScreen();

  Future<void> _confirmDelete(
    BuildContext context,
    AppLocalizations l10n,
    FinanceEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteFinanceEntryTitle),
        content: Text(l10n.deleteFinanceEntryMessage(entry.category)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await context.read<FinanceRepository>().deleteEntry(entry.id);
      } on ApiException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message)));
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.genericError)));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final repo = context.watch<FinanceRepository>();
    final auth = context.watch<AuthRepository>();
    final canCreate = auth.hasPermission('finance.create');
    final canDelete = auth.hasPermission('finance.delete');

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navFinance)),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/finance/new'),
              icon: const Icon(Icons.add),
              label: Text(l10n.financeAddNew),
            )
          : null,
      body: repo.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: repo.fetchAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (repo.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(repo.error!,
                          style: theme.textTheme.bodyMedium!
                              .copyWith(color: theme.colorScheme.error)),
                    ),
                  FilterChipsBar(
                    chips: [
                      FilterChipData(
                        label: l10n.financeFilterTypeChip,
                        isActive: repo.typeFilter.isNotEmpty,
                        onTap: () async {
                          final result = await showSingleSelectFilterSheet<String>(
                            context: context,
                            title: l10n.financeFilterTypeChip,
                            selected: repo.typeFilter,
                            clearValue: '',
                            options: [
                              FilterOption(value: '', label: l10n.financeTypeAll),
                              FilterOption(value: 'income', label: l10n.financeTypeIncome),
                              FilterOption(value: 'expense', label: l10n.financeTypeExpense),
                            ],
                          );
                          if (result != null) await repo.setTypeFilter(result);
                        },
                      ),
                      FilterChipData(
                        label: l10n.financeFilterPeriodChip,
                        isActive: repo.period != FinancePeriod.all,
                        onTap: () async {
                          final result = await showDateRangeFilterSheet(
                            context: context,
                            title: l10n.financeFilterPeriodChip,
                            presets: [
                              for (final period in FinancePeriod.values)
                                DateRangePresetOption(
                                  id: period.name,
                                  label: financePeriodLabel(l10n, period),
                                  subtitle: _periodRangeSubtitle(period),
                                ),
                            ],
                            customPresetId: FinancePeriod.custom.name,
                            selectedPresetId: repo.period.name,
                            customFrom: repo.customFrom,
                            customTo: repo.customTo,
                            customFromLabel: l10n.financeCustomFromLabel,
                            customToLabel: l10n.financeCustomToLabel,
                            customPickDateLabel: l10n.financeCustomPickDate,
                          );
                          if (result == null) return;
                          final targetPeriod =
                              FinancePeriod.values.byName(result.presetId);
                          if (targetPeriod == FinancePeriod.custom) {
                            await repo.setCustomRange(from: result.from, to: result.to);
                          }
                          if (repo.period != targetPeriod) {
                            await repo.setPeriod(targetPeriod);
                          }
                        },
                      ),
                      FilterChipData(
                        label: l10n.financeCategoryLabel,
                        isActive: repo.categoryFilter.isNotEmpty,
                        onTap: () async {
                          final result = await showSingleSelectFilterSheet<String>(
                            context: context,
                            title: l10n.financeCategoryLabel,
                            selected: repo.categoryFilter,
                            clearValue: '',
                            searchable: repo.availableCategories.length > 8,
                            options: [
                              FilterOption(value: '', label: l10n.financeCategoryAll),
                              for (final category in repo.availableCategories)
                                FilterOption(value: category, label: category),
                            ],
                          );
                          if (result != null) await repo.setCategoryFilter(result);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: l10n.financeIncomeLabel,
                          value: formatRupiah(repo.summary.totalIncome),
                          color: theme.colorScheme.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SummaryCard(
                          label: l10n.financeExpenseLabel,
                          value: formatRupiah(repo.summary.totalExpense),
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.financeNetLabel,
                              style: theme.textTheme.bodySmall),
                          Text(
                            formatRupiah(repo.summary.net),
                            style: theme.textTheme.titleLarge!.copyWith(
                              color: repo.summary.net >= 0
                                  ? theme.colorScheme.success
                                  : theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (repo.summary.incomeByCategory.isNotEmpty ||
                      repo.summary.expenseByCategory.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(l10n.financeByCategoryTitle,
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in repo.summary.incomeByCategory.entries)
                          _CategoryChip(
                            label: entry.key,
                            amount: entry.value,
                            color: theme.colorScheme.success,
                            prefix: '+',
                          ),
                        for (final entry in repo.summary.expenseByCategory.entries)
                          _CategoryChip(
                            label: entry.key,
                            amount: entry.value,
                            color: theme.colorScheme.error,
                            prefix: '-',
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(l10n.financeHistoryTitle,
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (repo.entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(Icons.account_balance_wallet_outlined,
                              size: 48, color: theme.colorScheme.primary),
                          const SizedBox(height: 12),
                          Text(l10n.financeEmptyTitle,
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(l10n.financeEmptyMessage,
                              style: theme.textTheme.bodySmall,
                              textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  else
                    for (final entry in repo.entries)
                      Dismissible(
                        key: ValueKey(entry.id),
                        direction: canDelete && !entry.isAuto
                            ? DismissDirection.endToStart
                            : DismissDirection.none,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          color: theme.colorScheme.error,
                          child: Icon(Icons.delete_outline,
                              color: theme.colorScheme.onError),
                        ),
                        confirmDismiss: (_) async {
                          await _confirmDelete(context, l10n, entry);
                          return false;
                        },
                        child: _FinanceEntryTile(entry: entry),
                      ),
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall!
                  .copyWith(color: theme.colorScheme.onError.withValues(alpha: 0.8))),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleLarge!
                .copyWith(color: theme.colorScheme.onError),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.amount,
    required this.color,
    required this.prefix,
  });

  final String label;
  final int amount;
  final Color color;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text('$prefix${formatRupiah(amount)}',
              style: theme.textTheme.titleSmall!.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _FinanceEntryTile extends StatelessWidget {
  const _FinanceEntryTile({required this.entry});

  final FinanceEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final color = entry.isIncome ? theme.colorScheme.success : theme.colorScheme.error;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                entry.isIncome
                    ? Icons.arrow_upward_outlined
                    : Icons.arrow_downward_outlined,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.category, style: theme.textTheme.titleSmall),
                  if (entry.pendingSync)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: SyncPendingBadge(),
                    )
                  else if (entry.isAuto)
                    Text(l10n.financeAutoBadge,
                        style: theme.textTheme.bodySmall!
                            .copyWith(color: theme.colorScheme.primary))
                  else if (entry.note != null && entry.note!.isNotEmpty)
                    Text(entry.note!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text(
              '${entry.isIncome ? '+' : '-'}${formatRupiah(entry.amount)}',
              style: theme.textTheme.titleSmall!.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
