import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/finance.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/finance_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';

String financePeriodLabel(AppLocalizations l10n, FinancePeriod period) =>
    switch (period) {
      FinancePeriod.all => l10n.financePeriodAll,
      FinancePeriod.today => l10n.financePeriodToday,
      FinancePeriod.week => l10n.financePeriodWeek,
      FinancePeriod.month => l10n.financePeriodMonth,
    };

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
      await context.read<FinanceRepository>().deleteEntry(entry.id);
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
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final (value, label) in [
                          ('', l10n.financeTypeAll),
                          ('income', l10n.financeTypeIncome),
                          ('expense', l10n.financeTypeExpense),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(label),
                              selected: repo.typeFilter == value,
                              onSelected: (_) => repo.setTypeFilter(value),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final period in FinancePeriod.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(financePeriodLabel(l10n, period)),
                              selected: repo.period == period,
                              onSelected: (_) => repo.setPeriod(period),
                            ),
                          ),
                      ],
                    ),
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
                        direction: canDelete
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

class _FinanceEntryTile extends StatelessWidget {
  const _FinanceEntryTile({required this.entry});

  final FinanceEntry entry;

  @override
  Widget build(BuildContext context) {
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
                  if (entry.note != null && entry.note!.isNotEmpty)
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
