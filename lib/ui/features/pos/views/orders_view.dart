import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/order.dart';
import '../../../../data/repositories/orders_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';
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
                                  order: viewModel.items[index]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

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
    );
  }
}
