import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/order.dart';
import '../../../../data/repositories/offline_queue_repository.dart';
import '../../../../data/repositories/orders_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/rupiah_field.dart';
import '../view_models/orders_view_model.dart';

String orderStatusLabel(AppLocalizations l10n, String status) =>
    switch (status) {
      'open' => l10n.statusOpen,
      'completed' => l10n.statusCompleted,
      'cancelled' => l10n.statusCancelled,
      'refunded' => l10n.statusRefunded,
      _ => status,
    };

String paymentStatusLabel(AppLocalizations l10n, String status) =>
    switch (status) {
      'unpaid' => l10n.paymentUnpaid,
      'partial' => l10n.paymentPartial,
      'paid' => l10n.paymentPaid,
      'refunded' => l10n.statusRefunded,
      _ => status,
    };

class OrdersView extends StatelessWidget {
  const OrdersView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => OrdersViewModel(
        ordersRepository: context.read<OrdersRepository>(),
      )..load(),
      child: const _OrdersScreen(),
    );
  }
}

class _OrdersScreen extends StatelessWidget {
  const _OrdersScreen();

  Future<void> _openDetail(BuildContext context, Order order) async {
    final viewModel = context.read<OrdersViewModel>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChangeNotifierProvider<OrdersViewModel>.value(
        value: viewModel,
        child: _OrderDetailSheet(order: order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final viewModel = context.watch<OrdersViewModel>();

    final filters = <(String, String)>[
      ('', l10n.statusAll),
      ('open', l10n.statusOpen),
      ('completed', l10n.statusCompleted),
      ('cancelled', l10n.statusCancelled),
      ('refunded', l10n.statusRefunded),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ordersTitle),
        leading: BackButton(onPressed: () => context.go('/pos')),
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
                    : viewModel.items.isEmpty
                        ? Center(
                            child: Text(l10n.ordersEmpty,
                                style: theme.textTheme.bodyMedium),
                          )
                        : RefreshIndicator(
                            onRefresh: viewModel.load,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: viewModel.items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) => _OrderCard(
                                order: viewModel.items[index],
                                onTap: () => _openDetail(
                                    context, viewModel.items[index]),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final time = DateFormat('d MMM HH:mm').format(order.createdAt.toLocal());

    Color statusColor(String status) => switch (status) {
          'completed' => theme.colorScheme.primary,
          'cancelled' || 'refunded' => theme.colorScheme.error,
          _ => theme.colorScheme.onSurface,
        };

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
                      order.orderNo ?? order.customerName ?? '—',
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(time, style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatRupiah(order.totalAmount),
                    style: theme.textTheme.titleMedium,
                  ),
                  Row(
                    children: [
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          orderStatusLabel(l10n, order.status),
                          style: theme.textTheme.bodySmall!.copyWith(
                              color: statusColor(order.status)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          paymentStatusLabel(l10n, order.paymentStatus),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail + action sheet for one order — mirrors berdikari-web
/// `pos/orders.vue`'s detail drawer: complete+pay for held orders, settle
/// for unpaid/partial completed orders, cancel for held orders, refund for
/// paid orders. Requires connectivity (these target orders already synced
/// to the server, unlike checkout).
class _OrderDetailSheet extends StatefulWidget {
  const _OrderDetailSheet({required this.order});

  final Order order;

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  final _payController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.order.balanceDue > 0) {
      _payController.text = formatRupiahDigits(widget.order.balanceDue);
    }
  }

  @override
  void dispose() {
    _payController.dispose();
    super.dispose();
  }

  Future<bool> _confirm(
    AppLocalizations l10n, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _run(BuildContext context, Future<Order?> Function() action) async {
    final order = await action();
    if (order != null && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final order = widget.order;
    final viewModel = context.watch<OrdersViewModel>();
    final offline = context.watch<OfflineQueueRepository>().isOffline;
    final showPayInput =
        order.status == 'open' || (order.status == 'completed' && order.balanceDue > 0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(order.orderNo ?? l10n.ordersTitle,
                    style: theme.textTheme.titleMedium),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(orderStatusLabel(l10n, order.status)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${item.quantity}× ${item.productName ?? 'Produk'}',
                        style: theme.textTheme.bodyMedium),
                    Text(formatRupiah(item.subtotal),
                        style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.totalLabel, style: theme.textTheme.bodyMedium),
                Text(formatRupiah(order.totalAmount),
                    style: theme.textTheme.titleSmall),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.paidLabel, style: theme.textTheme.bodyMedium),
                Text(formatRupiah(order.paidAmount),
                    style: theme.textTheme.bodyMedium),
              ],
            ),
            if (order.balanceDue > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.ordersBalanceDueLabel, style: theme.textTheme.bodyMedium),
                  Text(formatRupiah(order.balanceDue),
                      style: theme.textTheme.bodyMedium!
                          .copyWith(color: theme.colorScheme.warning)),
                ],
              ),
            if (showPayInput) ...[
              const SizedBox(height: 12),
              RupiahField(
                controller: _payController,
                label: l10n.cashReceivedLabel,
              ),
            ],
            if (offline) ...[
              const SizedBox(height: 12),
              Text(l10n.ordersRequiresConnection,
                  style: theme.textTheme.bodySmall!
                      .copyWith(color: theme.colorScheme.warning)),
            ],
            if (viewModel.actionError != null) ...[
              const SizedBox(height: 12),
              Text(viewModel.actionError!,
                  style: theme.textTheme.bodyMedium!
                      .copyWith(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            if (order.status == 'open') ...[
              ElevatedButton(
                onPressed: offline || viewModel.busy
                    ? null
                    : () => _run(
                        context,
                        () => viewModel.complete(
                            order.id, payment: parseRupiahInput(_payController.text))),
                child: viewModel.busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.ordersCompleteAction),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: offline || viewModel.busy
                    ? null
                    : () async {
                        final confirmed = await _confirm(
                          l10n,
                          title: l10n.ordersCancelConfirmTitle,
                          message: l10n.ordersCancelConfirmMessage,
                          confirmLabel: l10n.ordersCancelAction,
                        );
                        if (confirmed && context.mounted) {
                          await _run(context, () => viewModel.cancel(order.id));
                        }
                      },
                child: Text(l10n.ordersCancelAction,
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            ] else if (order.status == 'completed' && order.balanceDue > 0) ...[
              ElevatedButton(
                onPressed: offline || viewModel.busy
                    ? null
                    : () => _run(
                        context,
                        () => viewModel.pay(
                            order.id, parseRupiahInput(_payController.text))),
                child: viewModel.busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.ordersPayAction),
              ),
            ] else if (order.status == 'completed') ...[
              OutlinedButton(
                onPressed: offline || viewModel.busy
                    ? null
                    : () async {
                        final confirmed = await _confirm(
                          l10n,
                          title: l10n.ordersRefundConfirmTitle,
                          message: l10n.ordersRefundConfirmMessage,
                          confirmLabel: l10n.ordersRefundAction,
                        );
                        if (confirmed && context.mounted) {
                          await _run(context, () => viewModel.refund(order.id));
                        }
                      },
                child: viewModel.busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.ordersRefundAction),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  orderStatusLabel(l10n, order.status),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
