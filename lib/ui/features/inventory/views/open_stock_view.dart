import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/daily_stock_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';
import '../view_models/open_stock_view_model.dart';

class OpenStockView extends StatelessWidget {
  const OpenStockView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => OpenStockViewModel(
        dailyStockRepository: context.read<DailyStockRepository>(),
      )..init(),
      child: const _OpenStockScreen(),
    );
  }
}

class _OpenStockScreen extends StatelessWidget {
  const _OpenStockScreen();

  Future<void> _save(BuildContext context) async {
    final viewModel = context.read<OpenStockViewModel>();
    final success = await viewModel.save();
    if (success && context.mounted) context.go('/inventory');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final viewModel = context.watch<OpenStockViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.openStockToday),
        leading: BackButton(onPressed: () => context.go('/inventory')),
      ),
      body: viewModel.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    l10n.openStockInstruction,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Expanded(
                  child: viewModel.lines.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  l10n.openStockEmptyProducts,
                                  style: theme.textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => context.go('/catalog'),
                                  child: Text(l10n.goToCatalog),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: viewModel.lines.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final line = viewModel.lines[index];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(line.productName,
                                              style:
                                                  theme.textTheme.titleSmall),
                                          Text(
                                            [
                                              if (line.price != null)
                                                formatRupiah(line.price!),
                                              '${l10n.currentStockLabel}: ${line.currentStock}',
                                            ].join(' · '),
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      constraints: const BoxConstraints(
                                          minWidth: 44, minHeight: 44),
                                      icon: const Icon(
                                          Icons.remove_circle_outline),
                                      onPressed: () => viewModel
                                          .decrement(line.productId),
                                    ),
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        '${line.openingQty}',
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                    ),
                                    IconButton(
                                      constraints: const BoxConstraints(
                                          minWidth: 44, minHeight: 44),
                                      icon:
                                          const Icon(Icons.add_circle_outline),
                                      onPressed: () => viewModel
                                          .increment(line.productId),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (viewModel.totalOpening > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(l10n.totalStockOpened,
                                    style: theme.textTheme.bodyMedium),
                                Text(
                                  l10n.unitPcs(viewModel.totalOpening),
                                  style: theme.textTheme.titleMedium!
                                      .copyWith(
                                          color: theme.colorScheme.primary),
                                ),
                              ],
                            ),
                          ),
                        if (viewModel.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              viewModel.errorMessage!,
                              style: theme.textTheme.bodyMedium!.copyWith(
                                  color: theme.colorScheme.error),
                            ),
                          ),
                        ElevatedButton(
                          onPressed: (!viewModel.canSave || viewModel.saving)
                              ? null
                              : () => _save(context),
                          child: viewModel.saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : Text(l10n.openStockToday),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
