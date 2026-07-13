import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/order.dart';
import '../../../../data/repositories/cart_repository.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../../data/repositories/shift_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';
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
          : !shift.hasActiveShift
              ? _NoShiftBanner(l10n: l10n, theme: theme)
              : _ProductGrid(viewModel: viewModel, l10n: l10n, theme: theme),
      bottomNavigationBar: cart.isEmpty || !shift.hasActiveShift
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

class _NoShiftBanner extends StatelessWidget {
  const _NoShiftBanner({required this.l10n, required this.theme});

  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.schedule_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(l10n.noActiveShiftTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l10n.noActiveShiftMessage,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/pos/shift'),
              child: Text(l10n.openShiftButton),
            ),
          ],
        ),
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
          child: GridView.builder(
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
