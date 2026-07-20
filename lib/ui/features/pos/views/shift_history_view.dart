import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/shift.dart';
import '../../../../data/services/sales_service.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../view_models/shift_history_view_model.dart';
import 'shift_view.dart' show paymentMethodLabel;

class ShiftHistoryView extends StatelessWidget {
  const ShiftHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ShiftHistoryViewModel(
        salesService: context.read<SalesService>(),
      )..load(),
      child: const _ShiftHistoryScreen(),
    );
  }
}

class _ShiftHistoryScreen extends StatelessWidget {
  const _ShiftHistoryScreen();

  Future<void> _openDetail(BuildContext context, CashierShift shift) async {
    final viewModel = context.read<ShiftHistoryViewModel>();
    await viewModel.openDetail(shift.id);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChangeNotifierProvider<ShiftHistoryViewModel>.value(
        value: viewModel,
        child: const _ShiftDetailSheet(),
      ),
    );
    viewModel.closeDetail();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final viewModel = context.watch<ShiftHistoryViewModel>();

    final filters = <(String, String)>[
      ('', l10n.statusAll),
      ('open', l10n.shiftStatusOpen),
      ('closed', l10n.shiftStatusClosed),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shiftHistoryTitle),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final (value, label) in filters)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: viewModel.statusFilter == value,
                      onSelected: (_) => viewModel.setStatusFilter(value),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: viewModel.loading
                ? const Center(child: CircularProgressIndicator())
                : viewModel.error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(viewModel.error!,
                                style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: viewModel.load,
                              child: Text(l10n.retry),
                            ),
                          ],
                        ),
                      )
                    : viewModel.shifts.isEmpty
                        ? Center(
                            child: Text(l10n.shiftHistoryEmpty,
                                style: theme.textTheme.bodyMedium),
                          )
                        : RefreshIndicator(
                            onRefresh: viewModel.load,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: viewModel.shifts.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) => _ShiftCard(
                                shift: viewModel.shifts[index],
                                onTap: () => _openDetail(
                                    context, viewModel.shifts[index]),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.shift, required this.onTap});

  final CashierShift shift;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final opened = DateFormat('d MMM HH:mm').format(shift.openedAt.toLocal());

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      shift.cashierName ?? '—',
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(shift.isOpen
                        ? l10n.shiftStatusOpen
                        : l10n.shiftStatusClosed),
                  ),
                ],
              ),
              Text(opened, style: theme.textTheme.bodySmall),
              if (!shift.isOpen) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatRupiah(shift.totalSales),
                        style: theme.textTheme.titleSmall),
                    Text(
                      l10n.cashDifferenceValue(
                          formatRupiah(shift.cashDifference ?? 0)),
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: (shift.cashDifference ?? 0) < 0
                            ? theme.colorScheme.error
                            : theme.colorScheme.success,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ShiftDetailSheet extends StatelessWidget {
  const _ShiftDetailSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final viewModel = context.watch<ShiftHistoryViewModel>();
    final shift = viewModel.selected;

    if (viewModel.loadingDetail || shift == null) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    Widget row(String label, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              Text(value,
                  style: theme.textTheme.titleSmall!.copyWith(color: color)),
            ],
          ),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.shiftDetailTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            row(l10n.shiftCashierLabel, shift.cashierName ?? '—'),
            row(l10n.shiftOpenedAtLabel,
                DateFormat('d MMM HH:mm').format(shift.openedAt.toLocal())),
            if (shift.closedAt != null)
              row(l10n.shiftClosedAtLabel,
                  DateFormat('d MMM HH:mm').format(shift.closedAt!.toLocal())),
            row(l10n.openingCashLabel, formatRupiah(shift.openingCash)),
            if (shift.closingCash != null)
              row(l10n.closingCashLabel, formatRupiah(shift.closingCash!)),
            if (shift.expectedCash != null)
              row(l10n.expectedCashLabel, formatRupiah(shift.expectedCash!)),
            if (shift.cashDifference != null)
              row(
                l10n.cashDifferenceLabel,
                formatRupiah(shift.cashDifference!),
                color: shift.cashDifference! < 0
                    ? theme.colorScheme.error
                    : theme.colorScheme.success,
              ),
            row(l10n.totalSalesLabel, formatRupiah(shift.totalSales)),
            row(l10n.transactionCountLabel, '${shift.transactionCount}'),
            if (shift.paymentBreakdown.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l10n.shiftPaymentBreakdownTitle,
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final entry in shift.paymentBreakdown.entries)
                row(paymentMethodLabel(entry.key), formatRupiah(entry.value)),
            ],
            if (shift.closingNote != null && shift.closingNote!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l10n.closingNoteLabel, style: theme.textTheme.bodySmall),
              Text('"${shift.closingNote}"',
                  style: theme.textTheme.bodyMedium!
                      .copyWith(fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }
}
