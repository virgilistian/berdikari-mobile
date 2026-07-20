import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/order.dart';
import '../../../../data/repositories/cart_repository.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../../data/repositories/offline_queue_repository.dart';
import '../../../../data/repositories/shift_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../view_models/pos_view_model.dart';
import '../widgets/cart_sheet.dart';
import '../widgets/receipt_dialog.dart';

class PosView extends StatelessWidget {
  const PosView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PosViewModel(
        catalogRepository: context.read<CatalogRepository>(),
        shiftRepository: context.read<ShiftRepository>(),
      )..init(),
      child: const _PosScreen(),
    );
  }
}

class _PosScreen extends StatelessWidget {
  const _PosScreen();

  Future<void> _openCart(BuildContext context) async {
    final order = await showModalBottomSheet<Order>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider<CartRepository>.value(
            value: context.read<CartRepository>(),
          ),
        ],
        child: const CartSheet(),
      ),
    );
    if (order != null && context.mounted) {
      await showReceiptDialog(context, order);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final viewModel = context.watch<PosViewModel>();
    final shift = context.watch<ShiftRepository>();
    final cart = context.watch<CartRepository>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navPos),
        actions: [
          IconButton(
            tooltip: l10n.ordersTitle,
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.go('/pos/orders'),
          ),
          IconButton(
            tooltip: l10n.navShift,
            icon: const Icon(Icons.schedule_outlined),
            onPressed: () => context.go('/pos/shift'),
          ),
        ],
      ),
      body: !shift.loaded || viewModel.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (viewModel.showShiftReminder)
                  _ShiftReminderBanner(l10n: l10n, theme: theme, viewModel: viewModel),
                const _OfflineSyncBanner(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: TextField(
                    onChanged: viewModel.setSearchQuery,
                    decoration: InputDecoration(
                      hintText: l10n.posSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                Expanded(
                  child: _ProductGrid(viewModel: viewModel, l10n: l10n, theme: theme),
                ),
              ],
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outline),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.itemCount(cart.totalItems),
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            formatRupiah(cart.totalAmount),
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _openCart(context),
                      child: Text(l10n.payButton),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Dismissible reminder — shift is NOT required to sell (Project decision,
/// matches berdikari-web `pos/index.vue`: "Shift belum dibuka — transaksi
/// tetap bisa diproses.").
class _ShiftReminderBanner extends StatelessWidget {
  const _ShiftReminderBanner({
    required this.l10n,
    required this.theme,
    required this.viewModel,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final PosViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: theme.colorScheme.warning.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.schedule_outlined, size: 16, color: theme.colorScheme.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.shiftReminderMessage,
              style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.warning),
            ),
          ),
          TextButton(
            onPressed: () => context.go('/pos/shift'),
            child: Text(l10n.openShiftButton),
          ),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close),
            onPressed: viewModel.dismissShiftReminder,
          ),
        ],
      ),
    );
  }
}

/// Offline / sync status — mirrors berdikari-web `pos/index.vue`'s banner.
class _OfflineSyncBanner extends StatelessWidget {
  const _OfflineSyncBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final queue = context.watch<OfflineQueueRepository>();

    if (!queue.isOffline && queue.queuedCount == 0 && queue.failedOrders.isEmpty) {
      return const SizedBox.shrink();
    }

    final String message;
    if (queue.isOffline) {
      message = queue.queuedCount > 0
          ? l10n.posOfflineWithQueue(queue.queuedCount)
          : l10n.posOffline;
    } else if (queue.draining) {
      message = l10n.posSyncing(queue.queuedCount);
    } else if (queue.queuedCount > 0) {
      message = l10n.posQueuedWaiting(queue.queuedCount);
    } else {
      message = l10n.posRejectedByServer(queue.failedOrders.length);
    }

    return Container(
      width: double.infinity,
      color: queue.isOffline
          ? theme.colorScheme.warning.withValues(alpha: 0.1)
          : theme.colorScheme.primary.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(
            queue.isOffline ? Icons.wifi_off : Icons.sync,
            size: 16,
            color: queue.isOffline ? theme.colorScheme.warning : theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall!.copyWith(
                color: queue.isOffline ? theme.colorScheme.warning : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (queue.failedOrders.isNotEmpty)
            TextButton(
              onPressed: queue.discardAllFailed,
              child: Text(l10n.shiftDiscardFailed),
            ),
        ],
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({
    required this.viewModel,
    required this.l10n,
    required this.theme,
  });

  final PosViewModel viewModel;
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (viewModel.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(viewModel.error!, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => viewModel.loadCatalog(refresh: true),
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }
    if (viewModel.visibleProducts.isEmpty && viewModel.categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.posEmptyProducts,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final cart = context.read<CartRepository>();
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(l10n.categoryAll),
                  selected: viewModel.selectedCategoryId == null,
                  onSelected: (_) => viewModel.selectCategory(null),
                ),
              ),
              for (final category in viewModel.categories)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(category.name),
                    selected: viewModel.selectedCategoryId == category.id,
                    onSelected: (_) => viewModel.selectCategory(category.id),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: viewModel.visibleProducts.isEmpty
              ? Center(
                  child: Text(l10n.catalogSearchEmptyTitle,
                      style: theme.textTheme.bodyMedium),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.6,
                  ),
                  itemCount: viewModel.visibleProducts.length,
                  itemBuilder: (context, index) {
                    final product = viewModel.visibleProducts[index];
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => cart.addProduct(product),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                product.name,
                                style: theme.textTheme.titleSmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatRupiah(product.price),
                                style: theme.textTheme.bodySmall!.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
