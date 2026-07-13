import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/product.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';
import '../view_models/catalog_view_model.dart';
import '../widgets/product_form_sheet.dart';

class CatalogView extends StatelessWidget {
  const CatalogView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CatalogViewModel(
        catalogRepository: context.read<CatalogRepository>(),
      )..load(),
      child: const _CatalogScreen(),
    );
  }
}

class _CatalogScreen extends StatelessWidget {
  const _CatalogScreen();

  Future<void> _openForm(BuildContext context, {Product? product}) async {
    final viewModel = context.read<CatalogViewModel>();
    final changed = await showProductFormSheet(
      context,
      categories: viewModel.categories,
      product: product,
    );
    if (changed) viewModel.load(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final viewModel = context.watch<CatalogViewModel>();
    final auth = context.watch<AuthRepository>();
    final canManage =
        auth.hasAnyPermission(['catalog.create', 'catalog.update']);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.catalogTitle)),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () => _openForm(context),
              child: const Icon(Icons.add),
            )
          : null,
      body: viewModel.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: TextField(
                    onChanged: viewModel.setSearchQuery,
                    decoration: InputDecoration(
                      hintText: l10n.catalogSearchHint,
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                ),
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
                            selected:
                                viewModel.selectedCategoryId == category.id,
                            onSelected: (_) =>
                                viewModel.selectCategory(category.id),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: viewModel.products.isEmpty
                      ? _EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: l10n.catalogEmptyTitle,
                          message: l10n.catalogEmptyMessage,
                        )
                      : viewModel.filteredProducts.isEmpty
                          ? _EmptyState(
                              icon: Icons.search_off,
                              title: l10n.catalogSearchEmptyTitle,
                              message: l10n.catalogSearchEmptyMessage,
                              action: TextButton(
                                onPressed: viewModel.clearFilters,
                                child: Text(l10n.clearFilter),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 1.3,
                              ),
                              itemCount: viewModel.filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product =
                                    viewModel.filteredProducts[index];
                                return _ProductCard(
                                  product: product,
                                  canManage: canManage,
                                  onEdit: () =>
                                      _openForm(context, product: product),
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(message,
                style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.canManage,
    required this.onEdit,
  });

  final Product product;
  final bool canManage;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: product.isActive ? 1 : 0.6,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.categoryName ?? l10n.noCategoryLabel,
                      style: theme.textTheme.labelSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!product.isActive)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(l10n.inactiveLabel,
                          style: theme.textTheme.bodySmall),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                product.name,
                style: theme.textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      formatRupiah(product.price),
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (canManage)
                    IconButton(
                      constraints:
                          const BoxConstraints(minWidth: 44, minHeight: 44),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: onEdit,
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
