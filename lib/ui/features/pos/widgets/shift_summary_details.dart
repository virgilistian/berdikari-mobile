import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../data/models/finance.dart';
import '../../../../data/models/shift.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../views/shift_view.dart' show paymentMethodLabel;

/// Full shift recap: sales, payments, cash reconciliation, operational
/// expenses, net income and stock reconciliation — mirrors berdikari-web
/// `components/ShiftSummaryDetails.vue`. Shared by the close-shift wizard's
/// summary step and the shift-history detail sheet.
class ShiftSummaryDetails extends StatelessWidget {
  const ShiftSummaryDetails({
    super.key,
    required this.shift,
    required this.expenses,
  });

  final CashierShift shift;
  final List<FinanceEntry> expenses;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final netIncome = shift.netIncome ?? (shift.totalSales - shift.totalExpenses);
    final adjustments =
        shift.stockSummary.where((s) => s.adjustmentQty != 0).toList();

    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              child,
            ],
          ),
        );

    Widget box(Widget child) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        );

    Widget row(String label, String value, {Color? color, bool bold = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              Text(
                value,
                style: (bold
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.bodyMedium)!
                    .copyWith(color: color),
              ),
            ],
          ),
        );

    final duration = shift.closedAt == null
        ? '—'
        : () {
            final mins = shift.closedAt!.difference(shift.openedAt).inMinutes;
            return '${mins ~/ 60} jam ${mins % 60} menit';
          }();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section(
          l10n.shiftInfoSection,
          box(Column(
            children: [
              row(l10n.shiftCashierLabel, shift.cashierName ?? '—'),
              row(l10n.shiftOpenedAtLabel,
                  DateFormat('d MMM y, HH:mm').format(shift.openedAt.toLocal())),
              if (shift.closedAt != null) ...[
                row(l10n.shiftClosedAtLabel,
                    DateFormat('d MMM y, HH:mm').format(shift.closedAt!.toLocal())),
                row(l10n.shiftDurationLabel, duration),
              ],
            ],
          )),
        ),
        section(
          l10n.shiftSalesSummaryTitle,
          box(Row(
            children: [
              Expanded(
                  child: _Stat(
                      label: l10n.totalSalesLabel,
                      value: formatRupiah(shift.totalSales))),
              Expanded(
                  child: _Stat(
                      label: l10n.transactionCountLabel,
                      value: '${shift.transactionCount}')),
              Expanded(
                  child: _Stat(
                      label: l10n.shiftItemsSoldLabel,
                      value: '${shift.totalItemsSold}')),
            ],
          )),
        ),
        if (shift.paymentBreakdown.isNotEmpty)
          section(
            l10n.shiftPaymentBreakdownTitle,
            Column(
              children: [
                for (final entry in shift.paymentBreakdown.entries)
                  box(row(paymentMethodLabel(entry.key), formatRupiah(entry.value))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                        child: _Stat(
                            label: l10n.shiftTotalCashLabel,
                            value: formatRupiah(shift.cashSales))),
                    Expanded(
                        child: _Stat(
                            label: l10n.shiftTotalNonCashLabel,
                            value: formatRupiah(shift.nonCashSales))),
                  ],
                ),
              ],
            ),
          ),
        if (shift.expectedCash != null)
          section(
            l10n.shiftCashSummaryTitle,
            box(Column(
              children: [
                row(l10n.openingCashLabel, formatRupiah(shift.openingCash)),
                row('+ ${l10n.shiftCashSalesLine}', formatRupiah(shift.cashSales)),
                row('- ${l10n.shiftExpensesLine}', formatRupiah(shift.totalExpenses)),
                const Divider(height: 12),
                row(l10n.expectedCashLabel, formatRupiah(shift.expectedCash!),
                    bold: true),
                row(l10n.closingCashLabel, formatRupiah(shift.closingCash ?? 0)),
                const Divider(height: 12),
                row(
                  l10n.cashDifferenceLabel,
                  formatSignedRupiah(shift.cashDifference ?? 0),
                  bold: true,
                  color: (shift.cashDifference ?? 0) < 0
                      ? theme.colorScheme.error
                      : theme.colorScheme.success,
                ),
              ],
            )),
          ),
        section(
          l10n.shiftExpensesSection,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (expenses.isEmpty)
                Text(l10n.shiftExpensesEmpty, style: theme.textTheme.bodySmall)
              else
                for (final e in expenses)
                  box(Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.category, style: theme.textTheme.bodyMedium),
                              if (e.note != null && e.note!.isNotEmpty)
                                Text(e.note!, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        Text(formatRupiah(e.amount),
                            style: theme.textTheme.bodyMedium!
                                .copyWith(color: theme.colorScheme.error)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.shiftNetIncomeLabel, style: theme.textTheme.titleSmall),
              Text(
                formatRupiah(netIncome),
                style: theme.textTheme.headlineSmall!.copyWith(
                  color: netIncome >= 0
                      ? theme.colorScheme.success
                      : theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (shift.stockSummary.isNotEmpty)
          section(
            l10n.shiftStockSection,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                box(Row(
                  children: [
                    Expanded(
                        child: _Stat(
                            label: l10n.shiftStockOpeningLabel,
                            value:
                                '${shift.stockSummary.fold<int>(0, (s, i) => s + i.openingQty)}')),
                    Expanded(
                        child: _Stat(
                            label: l10n.shiftStockSoldLabel,
                            value:
                                '${shift.stockSummary.fold<int>(0, (s, i) => s + i.soldQty)}')),
                    Expanded(
                        child: _Stat(
                            label: l10n.shiftStockRemainingLabel,
                            value:
                                '${shift.stockSummary.fold<int>(0, (s, i) => s + i.closingQty)}')),
                  ],
                )),
                if (adjustments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(l10n.shiftStockAdjustmentsTitle,
                      style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  for (final a in adjustments)
                    box(Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.productName, style: theme.textTheme.bodyMedium),
                                if (a.adjustmentNote != null &&
                                    a.adjustmentNote!.isNotEmpty)
                                  Text('"${a.adjustmentNote}"',
                                      style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                          Text(
                            '${a.adjustmentQty > 0 ? '+' : ''}${a.adjustmentQty}',
                            style: theme.textTheme.titleSmall!.copyWith(
                              color: a.adjustmentQty > 0
                                  ? theme.colorScheme.success
                                  : theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    )),
                ],
              ],
            ),
          ),
        if (shift.closingNote != null && shift.closingNote!.isNotEmpty)
          box(Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.closingNoteLabel, style: theme.textTheme.bodySmall),
                Text('"${shift.closingNote}"',
                    style: theme.textTheme.bodyMedium!
                        .copyWith(fontStyle: FontStyle.italic)),
              ],
            ),
          )),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        Text(value, style: theme.textTheme.titleSmall),
      ],
    );
  }
}
