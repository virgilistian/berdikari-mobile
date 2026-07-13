import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../data/models/sales_summary.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/services/finance_service.dart';
import '../../../../data/services/inventory_service.dart';
import '../../../../data/services/sales_service.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../view_models/reports_view_model.dart';

String reportPeriodLabel(AppLocalizations l10n, ReportPeriod period) =>
    switch (period) {
      ReportPeriod.today => l10n.reportPeriodToday,
      ReportPeriod.days7 => l10n.reportPeriod7,
      ReportPeriod.days30 => l10n.reportPeriod30,
      ReportPeriod.days90 => l10n.reportPeriod90,
    };

String _paymentMethodLabel(AppLocalizations l10n, String method) => switch (method) {
      'cash' => l10n.methodCash,
      'qris' => l10n.methodQris,
      'transfer' => l10n.methodTransfer,
      _ => method,
    };

String _insightText(AppLocalizations l10n, ReportInsight insight) => switch (insight) {
      TopProductInsight(:final name, :final quantity) =>
        l10n.reportInsightTopProduct(name, quantity),
      BestDayInsight(:final date, :final total) =>
        l10n.reportInsightBestDay(_longDate(date), formatRupiah(total)),
      ReceivableInsight(:final amount) =>
        l10n.reportInsightReceivable(formatRupiah(amount)),
      NetLossInsight(:final amount) => l10n.reportInsightNetLoss(formatRupiah(amount)),
      LowStockInsight(:final count) => l10n.reportInsightLowStock(count),
    };

String _shortDate(DateTime date) => '${date.day}/${date.month}';

String _longDate(DateTime date) {
  const months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

class ReportsView extends StatelessWidget {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ReportsViewModel(
        salesService: context.read<SalesService>(),
        financeService: context.read<FinanceService>(),
        inventoryService: context.read<InventoryService>(),
        authRepository: context.read<AuthRepository>(),
      )..load(),
      child: const _ReportsScreen(),
    );
  }
}

class _ReportsScreen extends StatelessWidget {
  const _ReportsScreen();

  Future<void> _exportCsv(BuildContext context, AppLocalizations l10n) async {
    final vm = context.read<ReportsViewModel>();
    final csv = vm.buildCsv();
    if (csv.trim().isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(csv)),
            name: 'laporan-berdikari.csv',
            mimeType: 'text/csv',
          ),
        ],
        subject: l10n.reportsTitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final vm = context.watch<ReportsViewModel>();
    final auth = context.watch<AuthRepository>();
    final sales = vm.sales;
    final finance = vm.finance;
    final lowStock = vm.lowStock;
    final insights = vm.insights;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navReports),
        actions: [
          if (!vm.loading && auth.hasPermission('report.export'))
            IconButton(
              onPressed: () => _exportCsv(context, l10n),
              icon: const Icon(Icons.ios_share_outlined),
              tooltip: l10n.reportExportCsv,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: vm.load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final period in ReportPeriod.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(reportPeriodLabel(l10n, period)),
                        selected: vm.period == period,
                        onSelected: (_) => vm.setPeriod(period),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (vm.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.6,
                children: [
                  if (sales != null) ...[
                    _KpiCard(
                      label: l10n.reportGrossSales,
                      value: formatRupiah(sales.grossSales),
                      hint: l10n.homeTransactionCount(sales.orderCount),
                    ),
                    _KpiCard(
                      label: l10n.reportAverageTicket,
                      value: formatRupiah(sales.averageTicket),
                      hint: l10n.homePerTransaction,
                    ),
                  ],
                  if (finance != null)
                    _KpiCard(
                      label: l10n.reportNetCash,
                      value: formatRupiah(finance.net),
                      hint: l10n.financeExpenseLabel,
                      valueColor:
                          finance.net >= 0 ? theme.colorScheme.success : theme.colorScheme.error,
                    ),
                  if (sales != null)
                    _KpiCard(
                      label: l10n.reportTopPaymentMethod,
                      value: _topPaymentMethod(l10n, sales.paymentMethods),
                      hint: sales.paymentMethods.isEmpty
                          ? l10n.reportNoPayment
                          : formatRupiah(
                              sales.paymentMethods.values.reduce((a, b) => a > b ? a : b)),
                    ),
                ],
              ),
              if (insights.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.06),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb_outline,
                              size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(l10n.reportInsightsTitle, style: theme.textTheme.titleSmall),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final insight in insights)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text('•  ${_insightText(l10n, insight)}',
                              style: theme.textTheme.bodyMedium),
                        ),
                    ],
                  ),
                ),
              ],
              if (sales != null) ...[
                const SizedBox(height: 20),
                Text(l10n.reportSalesSection, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                _DailySalesChart(daily: sales.daily, emptyLabel: l10n.reportDailySalesEmpty),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.reportTopProducts, style: theme.textTheme.bodySmall),
                        const SizedBox(height: 8),
                        if (sales.topProducts.isEmpty)
                          Text(l10n.reportTopProductsEmpty, style: theme.textTheme.bodyMedium)
                        else
                          for (final (index, product) in sales.topProducts.take(5).indexed)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor:
                                        theme.colorScheme.primary.withValues(alpha: 0.1),
                                    child: Text('${index + 1}',
                                        style: theme.textTheme.bodySmall!
                                            .copyWith(color: theme.colorScheme.primary)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(product.name ?? l10n.reportDeletedProduct,
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  Text('${product.quantity}x',
                                      style: theme.textTheme.bodyMedium),
                                  const SizedBox(width: 8),
                                  Text(formatRupiah(product.subtotal),
                                      style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ],
              if (finance != null) ...[
                const SizedBox(height: 20),
                Text(l10n.reportFinanceSection, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _CategoryBreakdownCard(
                        title: l10n.reportIncomeByCategory,
                        breakdown: finance.incomeByCategory,
                        color: theme.colorScheme.success,
                        emptyLabel: l10n.reportNoData,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CategoryBreakdownCard(
                        title: l10n.reportExpenseByCategory,
                        breakdown: finance.expenseByCategory,
                        color: theme.colorScheme.error,
                        emptyLabel: l10n.reportNoData,
                      ),
                    ),
                  ],
                ),
              ],
              if (lowStock != null) ...[
                const SizedBox(height: 20),
                Text(l10n.reportStockSection, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: lowStock.isEmpty
                        ? Row(
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 18, color: theme.colorScheme.success),
                              const SizedBox(width: 8),
                              Text(l10n.reportLowStockEmpty,
                                  style: theme.textTheme.bodyMedium),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final row in lowStock)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                          child: Text(row.productName,
                                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      Text(l10n.remainingOfMin(row.quantity, row.minStock),
                                          style: theme.textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _topPaymentMethod(AppLocalizations l10n, Map<String, int> methods) {
    if (methods.isEmpty) return '—';
    final top = methods.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return _paymentMethodLabel(l10n, top.key);
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.hint,
    this.valueColor,
  });

  final String label;
  final String value;
  final String hint;
  final Color? valueColor;

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
            Text(value,
                style: theme.textTheme.titleLarge!.copyWith(color: valueColor)),
            Text(hint, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _DailySalesChart extends StatelessWidget {
  const _DailySalesChart({required this.daily, required this.emptyLabel});

  final List<DailySales> daily;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (daily.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(emptyLabel,
                style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    final maxTotal = daily.map((d) => d.total).fold<int>(0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final day in daily)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: maxTotal > 0
                              ? (88 * day.total / maxTotal).clamp(4, 88)
                              : 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.8),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _shortDate(DateTime.parse(day.date)),
                          style: theme.textTheme.labelSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({
    required this.title,
    required this.breakdown,
    required this.color,
    required this.emptyLabel,
  });

  final String title;
  final Map<String, int> breakdown;
  final Color color;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            if (entries.isEmpty)
              Text(emptyLabel, style: theme.textTheme.bodySmall)
            else
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(entry.key,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(formatRupiah(entry.value),
                          style: theme.textTheme.bodySmall!.copyWith(color: color)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
