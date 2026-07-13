import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/order.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/services/finance_service.dart';
import '../../../../data/services/inventory_service.dart';
import '../../../../data/services/sales_service.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../view_models/home_view_model.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => HomeViewModel(
        salesService: context.read<SalesService>(),
        financeService: context.read<FinanceService>(),
        inventoryService: context.read<InventoryService>(),
        authRepository: context.read<AuthRepository>(),
      )..load(),
      child: const _HomeScreen(),
    );
  }
}

class _KpiCardData {
  const _KpiCardData({required this.label, required this.value, required this.hint});
  final String label;
  final String value;
  final String hint;
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  List<_KpiCardData> _kpiCards(AppLocalizations l10n, HomeViewModel vm) {
    final cards = <_KpiCardData>[];
    final salesToday = vm.salesToday;
    if (salesToday != null) {
      cards.add(_KpiCardData(
        label: l10n.homeSalesTodayLabel,
        value: formatRupiah(salesToday.grossSales),
        hint: l10n.homeTransactionCount(salesToday.orderCount),
      ));
      cards.add(_KpiCardData(
        label: l10n.homeAverageTicketLabel,
        value: formatRupiah(salesToday.averageTicket),
        hint: l10n.homePerTransaction,
      ));
    }
    if (vm.cashNet != null) {
      cards.add(_KpiCardData(
        label: l10n.homeCashTodayLabel,
        value: formatRupiah(vm.cashNet!),
        hint: l10n.homeCashInHint(formatRupiah(vm.cashIncome ?? 0)),
      ));
    }
    if (vm.lowStockCount != null) {
      cards.add(_KpiCardData(
        label: l10n.lowStockLabel,
        value: '${vm.lowStockCount}',
        hint: vm.lowStockCount! > 0
            ? l10n.homeLowStockNeedsRefill
            : l10n.homeLowStockSafe,
      ));
    }
    return cards;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final auth = context.watch<AuthRepository>();
    final vm = context.watch<HomeViewModel>();
    final user = auth.user;
    final cards = _kpiCards(l10n, vm);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: vm.load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(formatIndonesianDate(DateTime.now()),
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(l10n.homeGreetingUser(user?.name ?? ''),
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            if (vm.loadingKpi)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.6,
                children: List.generate(
                  2,
                  (_) => const Card(child: SizedBox.expand()),
                ),
              )
            else if (cards.isNotEmpty)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.6,
                children: [for (final card in cards) _KpiCard(data: card)],
              ),
            const SizedBox(height: 16),
            if (vm.primaryAction != null)
              _PrimaryActionCard(action: vm.primaryAction!),
            const SizedBox(height: 16),
            _SecondaryActions(auth: auth),
            if (auth.hasPermission('pos.view')) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.homeRecentTransactionsTitle,
                      style: theme.textTheme.titleSmall),
                  TextButton(
                    onPressed: () => context.go('/pos/orders'),
                    child: Text(l10n.homeSeeAll),
                  ),
                ],
              ),
              if (vm.loadingTransactions)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (vm.recentOrders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 40, color: theme.colorScheme.primary),
                      const SizedBox(height: 8),
                      Text(l10n.homeNoTransactionsTitle,
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(l10n.homeNoTransactionsMessage,
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center),
                    ],
                  ),
                )
              else
                for (final order in vm.recentOrders) _RecentOrderTile(order: order),
            ],
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});

  final _KpiCardData data;

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
            Text(data.label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(data.value, style: theme.textTheme.titleLarge),
            Text(data.hint, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard({required this.action});

  final PrimaryAction action;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final (title, subtitle, cta, route) = switch (action) {
      PrimaryAction.openShift => (
          l10n.homeActionOpenShiftTitle,
          l10n.homeActionOpenShiftSubtitle,
          l10n.homeActionOpenShiftCta,
          '/pos',
        ),
      PrimaryAction.addFinanceEntry => (
          l10n.homeActionFinanceTitle,
          l10n.homeActionFinanceSubtitle,
          l10n.homeActionFinanceCta,
          '/finance/new',
        ),
      PrimaryAction.openDailyStock => (
          l10n.homeActionDailyStockTitle,
          l10n.homeActionDailyStockSubtitle,
          l10n.homeActionDailyStockCta,
          '/inventory/new',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleMedium!
                        .copyWith(color: theme.colorScheme.onPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: theme.textTheme.bodySmall!.copyWith(
                        color: theme.colorScheme.onPrimary.withValues(alpha: 0.7))),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: theme.colorScheme.primary,
            ),
            onPressed: () => context.go(route),
            child: Text(cta),
          ),
        ],
      ),
    );
  }
}

class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions({required this.auth});

  final AuthRepository auth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final actions = <(String, IconData, String)>[
      if (auth.hasPermission('finance.create'))
        (l10n.homeQuickFinance, Icons.add_circle_outline, '/finance/new'),
      if (auth.hasPermission('inventory.create'))
        (l10n.homeQuickDailyStock, Icons.assignment_outlined, '/inventory/new'),
      if (auth.hasPermission('report.view'))
        (l10n.homeQuickReports, Icons.bar_chart, '/reports'),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.1,
      children: [
        for (final (label, icon, route) in actions)
          _SecondaryActionTile(label: label, icon: icon, route: route),
      ],
    );
  }
}

class _SecondaryActionTile extends StatelessWidget {
  const _SecondaryActionTile({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(route),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  const _RecentOrderTile({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final paid = order.paymentStatus == 'paid';
    final time = DateFormat('HH:mm').format(order.createdAt.toLocal());
    final label =
        '${order.items.length} item · ${order.customerName ?? order.orderNo ?? l10n.homeUnnamedOrder}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: (paid ? theme.colorScheme.success : theme.colorScheme.warning)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                paid ? Icons.check_circle_outline : Icons.schedule_outlined,
                size: 16,
                color: paid ? theme.colorScheme.success : theme.colorScheme.warning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(time, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Text(formatRupiah(order.totalAmount), style: theme.textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}
