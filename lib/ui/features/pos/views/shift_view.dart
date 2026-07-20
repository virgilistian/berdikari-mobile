import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/shift.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/offline_queue_repository.dart';
import '../../../../data/repositories/shift_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/rupiah_field.dart';
import '../view_models/shift_view_model.dart';

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
      body = _CloseShiftForm(shift: shift.activeShift!);
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

class _CloseShiftForm extends StatefulWidget {
  const _CloseShiftForm({required this.shift});

  final CashierShift shift;

  @override
  State<_CloseShiftForm> createState() => _CloseShiftFormState();
}

class _CloseShiftFormState extends State<_CloseShiftForm> {
  final _formKey = GlobalKey<FormState>();
  final _closingController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Recompute the live cash-difference preview on every keystroke.
    _closingController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _closingController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final viewModel = context.watch<ShiftViewModel>();
    final auth = context.watch<AuthRepository>();
    final canClose = auth.hasPermission('pos.close');
    final shift = widget.shift;
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
              ElevatedButton(
                onPressed: viewModel.submitting
                    ? null
                    : () {
                        if (!_formKey.currentState!.validate()) return;
                        viewModel.closeShift(
                          closingCash:
                              parseRupiahInput(_closingController.text),
                          note: _noteController.text.trim(),
                        );
                      },
                child: viewModel.submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.closeShiftButton),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClosedSummary extends StatelessWidget {
  const _ClosedSummary({required this.summary});

  final CashierShift summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final viewModel = context.read<ShiftViewModel>();
    final difference = summary.cashDifference ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.shiftClosedTitle,
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _KeyValueRow(
                      l10n.openingCashLabel, formatRupiah(summary.openingCash)),
                  _KeyValueRow(l10n.transactionCountLabel,
                      '${summary.transactionCount}'),
                  _KeyValueRow(
                      l10n.totalSalesLabel, formatRupiah(summary.totalSales)),
                  _KeyValueRow(l10n.expectedCashLabel,
                      formatRupiah(summary.expectedCash ?? 0)),
                  _KeyValueRow(l10n.closingCashLabel,
                      formatRupiah(summary.closingCash ?? 0)),
                  _KeyValueRow(
                    l10n.cashDifferenceLabel,
                    formatRupiah(difference),
                    valueColor: difference < 0
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
          if (summary.paymentBreakdown.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l10n.shiftPaymentBreakdownTitle,
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final entry in summary.paymentBreakdown.entries)
              _KeyValueRow(
                paymentMethodLabel(entry.key),
                formatRupiah(entry.value),
              ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: viewModel.dismissSummary,
            child: Text(l10n.shiftSummaryDone),
          ),
        ],
      ),
    );
  }
}
