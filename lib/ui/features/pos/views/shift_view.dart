import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/daily_stock.dart';
import '../../../../data/models/finance.dart';
import '../../../../data/models/shift.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/daily_stock_repository.dart';
import '../../../../data/repositories/finance_repository.dart';
import '../../../../data/repositories/offline_queue_repository.dart';
import '../../../../data/repositories/shift_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/rupiah_field.dart';
import '../view_models/shift_view_model.dart';
import '../widgets/shift_summary_details.dart';

const _paymentMethodLabels = {
  'cash': 'Tunai',
  'qris': 'QRIS',
  'transfer': 'Transfer',
};

String paymentMethodLabel(String method) => _paymentMethodLabels[method] ?? method;

class ShiftView extends StatelessWidget {
  const ShiftView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ShiftViewModel(
        shiftRepository: context.read<ShiftRepository>(),
      )..init(),
      child: const _ShiftScreen(),
    );
  }
}

class _ShiftScreen extends StatelessWidget {
  const _ShiftScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final viewModel = context.watch<ShiftViewModel>();
    final shift = context.watch<ShiftRepository>();
    final auth = context.watch<AuthRepository>();

    final Widget body;
    if (!shift.loaded) {
      body = const Center(child: CircularProgressIndicator());
    } else if (viewModel.closedSummary != null) {
      body = _ClosedSummary(summary: viewModel.closedSummary!);
    } else if (shift.hasActiveShift) {
      body = _ActiveShiftSummary(shift: shift.activeShift!);
    } else if (auth.hasPermission('pos.open')) {
      body = const _OpenShiftForm();
    } else {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.noActiveShiftTitle,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navShift),
        actions: [
          IconButton(
            tooltip: l10n.shiftHistoryTitle,
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/pos/shift/history'),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow(this.label, this.value, {this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.titleSmall!
                .copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}

/// Offline-queue status: queued count (auto-syncing) and any failed
/// (server-rejected) orders the cashier can discard.
class _OfflineQueueStatus extends StatelessWidget {
  const _OfflineQueueStatus();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final queue = context.watch<OfflineQueueRepository>();

    if (queue.queuedCount == 0 && queue.failedOrders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: theme.colorScheme.warning.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (queue.queuedCount > 0)
              Text(
                l10n.shiftQueuedTransactions(queue.queuedCount),
                style: theme.textTheme.bodyMedium!
                    .copyWith(color: theme.colorScheme.warning),
              ),
            if (queue.failedOrders.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                l10n.shiftFailedTransactions(queue.failedOrders.length),
                style: theme.textTheme.bodyMedium!
                    .copyWith(color: theme.colorScheme.error),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: queue.discardAllFailed,
                  child: Text(l10n.shiftDiscardFailed),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OpenShiftForm extends StatefulWidget {
  const _OpenShiftForm();

  @override
  State<_OpenShiftForm> createState() => _OpenShiftFormState();
}

class _OpenShiftFormState extends State<_OpenShiftForm> {
  final _formKey = GlobalKey<FormState>();
  final _openingController = TextEditingController();

  @override
  void dispose() {
    _openingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final viewModel = context.watch<ShiftViewModel>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _OfflineQueueStatus(),
            Text(l10n.noActiveShiftTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(l10n.noActiveShiftMessage, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            if (viewModel.errorMessage != null) ...[
              Text(
                viewModel.errorMessage!,
                style: theme.textTheme.bodyMedium!
                    .copyWith(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            RupiahField(
              controller: _openingController,
              label: l10n.openingCashLabel,
              validator: (value) => (value == null || value.isEmpty)
                  ? l10n.openingCashRequired
                  : null,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: viewModel.submitting
                  ? null
                  : () {
                      if (!_formKey.currentState!.validate()) return;
                      viewModel.openShift(
                        openingCash:
                            parseRupiahInput(_openingController.text),
                      );
                    },
              child: viewModel.submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.openShiftButton),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact active-shift banner + "Tutup Shift" entry point. Deliberately
/// does not fetch daily-stock data itself — that only happens once the
/// close-shift wizard sheet actually opens, matching berdikari-web
/// `shift.vue`'s button-opens-drawer pattern (rather than eagerly loading
/// stock data just because a shift happens to be open).
class _ActiveShiftSummary extends StatelessWidget {
  const _ActiveShiftSummary({required this.shift});

  final CashierShift shift;

  Future<void> _openCloseWizard(BuildContext context) async {
    final viewModel = context.read<ShiftViewModel>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChangeNotifierProvider<ShiftViewModel>.value(
        value: viewModel,
        child: _CloseShiftWizard(shift: shift),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final auth = context.watch<AuthRepository>();
    final canClose = auth.hasPermission('pos.close');
    final openedTime = DateFormat.Hm().format(shift.openedAt.toLocal());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _OfflineQueueStatus(),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.shiftActiveBanner(openedTime),
                    style: theme.textTheme.titleSmall!
                        .copyWith(color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 8),
                  _KeyValueRow(
                      l10n.openingCashLabel, formatRupiah(shift.openingCash)),
                  _KeyValueRow(l10n.transactionCountLabel,
                      '${shift.transactionCount}'),
                  _KeyValueRow(
                      l10n.totalSalesLabel, formatRupiah(shift.totalSales)),
                ],
              ),
            ),
          ),
          if (shift.paymentBreakdown.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l10n.shiftPaymentBreakdownTitle,
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final entry in shift.paymentBreakdown.entries)
              _KeyValueRow(
                paymentMethodLabel(entry.key),
                formatRupiah(entry.value),
              ),
          ],
          const SizedBox(height: 16),
          if (!canClose)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                l10n.shiftCloseNotPermitted,
                style: theme.textTheme.bodySmall,
              ),
            )
          else
            ElevatedButton(
              onPressed: () => _openCloseWizard(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              child: Text(l10n.closeShiftButton),
            ),
        ],
      ),
    );
  }
}

/// Stock physical-count line being edited during the close-shift wizard's
/// reconciliation step.
class _StockAdjustment {
  _StockAdjustment(this.physical) : reasonController = TextEditingController();
  int physical;
  final TextEditingController reasonController;
}

/// Close-shift wizard: stock reconciliation -> cash closing. Mirrors
/// berdikari-web `pos/shift.vue`'s `showCloseForm` drawer steps 1-2 (step 3,
/// the summary, is rendered separately once [ShiftViewModel.closedSummary]
/// is set — see `_ShiftScreen`).
class _CloseShiftWizard extends StatefulWidget {
  const _CloseShiftWizard({required this.shift});

  final CashierShift shift;

  @override
  State<_CloseShiftWizard> createState() => _CloseShiftWizardState();
}

class _CloseShiftWizardState extends State<_CloseShiftWizard> {
  final _formKey = GlobalKey<FormState>();
  final _closingController = TextEditingController();
  final _noteController = TextEditingController();

  String _step = 'stock';
  final Map<String, _StockAdjustment> _adjustments = {};
  bool _stockSubmitting = false;
  String? _stockError;

  @override
  void initState() {
    super.initState();
    _closingController.addListener(() => setState(() {}));
    final repo = context.read<DailyStockRepository>();
    if (!repo.hasStocks) {
      repo.fetchToday().then((_) => _seedAdjustments());
    } else {
      _seedAdjustments();
    }
  }

  void _seedAdjustments() {
    final repo = context.read<DailyStockRepository>();
    for (final item in repo.stocks) {
      _adjustments.putIfAbsent(
          item.productId, () => _StockAdjustment(item.remainingQty));
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _closingController.dispose();
    _noteController.dispose();
    for (final a in _adjustments.values) {
      a.reasonController.dispose();
    }
    super.dispose();
  }

  bool _stockStepValid(List<DailyStockItem> stocks) {
    for (final item in stocks) {
      final adj = _adjustments[item.productId];
      if (adj == null) return false;
      if (adj.physical == item.remainingQty) continue;
      if (adj.reasonController.text.trim().isEmpty) return false;
    }
    return true;
  }

  Future<void> _submitStockStep(List<DailyStockItem> stocks) async {
    setState(() {
      _stockSubmitting = true;
      _stockError = null;
    });
    final repo = context.read<DailyStockRepository>();
    try {
      for (final item in stocks) {
        final adj = _adjustments[item.productId];
        if (adj == null) continue;
        final delta = adj.physical - item.remainingQty;
        if (delta != 0) {
          await repo.adjustStock(item.productId, delta,
              note: adj.reasonController.text.trim());
        }
      }
      if (mounted) setState(() => _step = 'cash');
    } catch (_) {
      if (mounted) {
        setState(() =>
            _stockError = 'Penyesuaian stok belum bisa disimpan. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _stockSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final viewModel = context.watch<ShiftViewModel>();
    final auth = context.watch<AuthRepository>();
    final dailyStock = context.watch<DailyStockRepository>();
    final canClose = auth.hasPermission('pos.close');
    final shift = widget.shift;

    if (_step == 'stock') {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.shiftStockReconTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(l10n.shiftStockReconMessage, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            if (dailyStock.loading)
              const Center(child: CircularProgressIndicator())
            else if (dailyStock.stocks.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(l10n.shiftStockReconEmpty,
                    style: theme.textTheme.bodySmall),
              )
            else
              for (final item in dailyStock.stocks)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(item.productName,
                                  style: theme.textTheme.titleSmall,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text(
                              l10n.shiftStockReconSystemLine(
                                  item.openingQty, item.soldQty, item.remainingQty),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(l10n.shiftStockPhysicalLabel,
                                style: theme.textTheme.bodySmall),
                            const SizedBox(width: 8),
                            IconButton(
                              constraints: const BoxConstraints(
                                  minWidth: 44, minHeight: 44),
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () {
                                final adj = _adjustments[item.productId];
                                if (adj == null || adj.physical <= 0) return;
                                setState(() => adj.physical--);
                              },
                            ),
                            SizedBox(
                              width: 40,
                              child: Text(
                                '${_adjustments[item.productId]?.physical ?? item.remainingQty}',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              constraints: const BoxConstraints(
                                  minWidth: 44, minHeight: 44),
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () {
                                final adj = _adjustments[item.productId];
                                if (adj == null) return;
                                setState(() => adj.physical++);
                              },
                            ),
                          ],
                        ),
                        if ((_adjustments[item.productId]?.physical ??
                                item.remainingQty) !=
                            item.remainingQty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextField(
                              controller: _adjustments[item.productId]
                                  ?.reasonController,
                              decoration: InputDecoration(
                                labelText: l10n.shiftStockReasonLabel,
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            if (_stockError != null) ...[
              const SizedBox(height: 8),
              Text(_stockError!,
                  style: theme.textTheme.bodySmall!
                      .copyWith(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: (dailyStock.loading ||
                      _stockSubmitting ||
                      !_stockStepValid(dailyStock.stocks))
                  ? null
                  : () => _submitStockStep(dailyStock.stocks),
              child: _stockSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(dailyStock.stocks.isEmpty
                      ? l10n.shiftStockSkip
                      : l10n.shiftStockContinue),
            ),
          ],
        ),
      );
    }

    // Step 2: cash closing.
    final openedTime = DateFormat.Hm().format(shift.openedAt.toLocal());
    final hasClosingInput = _closingController.text.isNotEmpty;
    final cashDiff = hasClosingInput
        ? parseRupiahInput(_closingController.text) - shift.expectedCashLive()
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _OfflineQueueStatus(),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.shiftActiveBanner(openedTime),
                      style: theme.textTheme.titleSmall!
                          .copyWith(color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                    _KeyValueRow(
                        l10n.openingCashLabel, formatRupiah(shift.openingCash)),
                    _KeyValueRow(l10n.transactionCountLabel,
                        '${shift.transactionCount}'),
                    _KeyValueRow(l10n.shiftItemsSoldLabel,
                        '${shift.totalItemsSold}'),
                    _KeyValueRow(
                        l10n.totalSalesLabel, formatRupiah(shift.totalSales)),
                  ],
                ),
              ),
            ),
            if (shift.paymentBreakdown.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.shiftPaymentBreakdownTitle,
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final entry in shift.paymentBreakdown.entries)
                _KeyValueRow(
                  paymentMethodLabel(entry.key),
                  formatRupiah(entry.value),
                ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.shiftCashSummaryTitle, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  _KeyValueRow(l10n.openingCashLabel, formatRupiah(shift.openingCash)),
                  _KeyValueRow(
                      '+ ${l10n.shiftCashSalesLine}', formatRupiah(shift.cashSales)),
                  _KeyValueRow('- ${l10n.shiftExpensesLine}',
                      formatRupiah(shift.totalExpenses)),
                  const Divider(height: 12),
                  _KeyValueRow(l10n.expectedCashLabel,
                      formatRupiah(shift.expectedCashLive())),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!canClose)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l10n.shiftCloseNotPermitted,
                  style: theme.textTheme.bodySmall,
                ),
              )
            else ...[
              if (viewModel.errorMessage != null) ...[
                Text(
                  viewModel.errorMessage!,
                  style: theme.textTheme.bodyMedium!
                      .copyWith(color: theme.colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              RupiahField(
                controller: _closingController,
                label: l10n.closingCashLabel,
                validator: (value) => (value == null || value.isEmpty)
                    ? l10n.closingCashRequired
                    : null,
              ),
              if (hasClosingInput)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l10n.cashDifferenceValue(formatRupiah(cashDiff)),
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: cashDiff < 0
                          ? theme.colorScheme.error
                          : cashDiff > 0
                              ? theme.colorScheme.success
                              : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(labelText: l10n.closingNoteLabel),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _step = 'stock'),
                      child: Text(l10n.back),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: viewModel.submitting
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) return;
                              final ok = await viewModel.closeShift(
                                closingCash:
                                    parseRupiahInput(_closingController.text),
                                note: _noteController.text.trim(),
                              );
                              // Close the wizard sheet; the shift screen
                              // underneath shows the summary once
                              // `closedSummary` is set.
                              if (ok && context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                      child: viewModel.submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.closeShiftButton),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Step 3 of the close-shift wizard: full recap + operational expenses for
/// the just-closed shift — mirrors berdikari-web `shift.vue`'s summary step.
class _ClosedSummary extends StatefulWidget {
  const _ClosedSummary({required this.summary});

  final CashierShift summary;

  @override
  State<_ClosedSummary> createState() => _ClosedSummaryState();
}

class _ClosedSummaryState extends State<_ClosedSummary> {
  List<FinanceEntry> _expenses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    context
        .read<FinanceRepository>()
        .fetchShiftExpenses(widget.summary.id)
        .then((expenses) {
      if (mounted) {
        setState(() {
          _expenses = expenses;
          _loading = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final viewModel = context.read<ShiftViewModel>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.success.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text(l10n.shiftClosedTitle,
                  style: theme.textTheme.titleSmall!
                      .copyWith(color: theme.colorScheme.success)),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            ShiftSummaryDetails(shift: widget.summary, expenses: _expenses),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: viewModel.dismissSummary,
            child: Text(l10n.shiftSummaryDone),
          ),
        ],
      ),
    );
  }
}
