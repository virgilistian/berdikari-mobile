import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/daily_stock_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../view_models/open_stock_view_model.dart';

class OpenStockView extends StatelessWidget {
  const OpenStockView({super.key, this.initialDate});

  /// Deep-linked date (`?date=YYYY-MM-DD`) from the draft detail page's
  /// "Edit" action.
  final String? initialDate;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => OpenStockViewModel(
        dailyStockRepository: context.read<DailyStockRepository>(),
        initialDate: initialDate,
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

  Future<void> _pickDate(BuildContext context) async {
    final viewModel = context.read<OpenStockViewModel>();
    final min = viewModel.minDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(viewModel.selectedDate) ?? min,
      firstDate: min,
      lastDate: min.add(const Duration(days: 365)),
    );
    if (picked != null) {
      await viewModel.setDate(picked.toIso8601String().split('T').first);
    }
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pickDate(context),
                        icon: const Icon(Icons.calendar_today_outlined, size: 16),
                        label: Text(viewModel.selectedDate),
                      ),
                      const SizedBox(height: 4),
                      Text(l10n.openStockDateHint, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Text(l10n.openStockInstruction, style: theme.textTheme.bodyMedium),
                    ],
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
                            final isLow = line.currentStock <= 5;
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: line.imageUrl != null
                                            ? Image.network(
                                                line.imageUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) =>
                                                    _ProductPlaceholder(theme: theme),
                                              )
                                            : _ProductPlaceholder(theme: theme),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(line.productName,
                                              style:
                                                  theme.textTheme.titleSmall,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                          Row(
                                            children: [
                                              if (line.price != null) ...[
                                                Text(formatRupiah(line.price!),
                                                    style: theme
                                                        .textTheme.bodySmall),
                                                const SizedBox(width: 6),
                                                Text('·',
                                                    style: theme
                                                        .textTheme.bodySmall),
                                                const SizedBox(width: 6),
                                              ],
                                              Flexible(
                                                child: Text(
                                                  '${l10n.currentStockLabel}: ${line.currentStock}',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: theme.textTheme.bodySmall!
                                                      .copyWith(
                                                    color: isLow
                                                        ? theme.colorScheme.warning
                                                        : null,
                                                    fontWeight: isLow
                                                        ? FontWeight.w600
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                            ],
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
                                      width: 44,
                                      child: TextField(
                                        key: ValueKey(
                                            '${line.productId}-${line.openingQty}'),
                                        controller: TextEditingController(
                                            text: '${line.openingQty}'),
                                        textAlign: TextAlign.center,
                                        keyboardType: TextInputType.number,
                                        style: theme.textTheme.titleMedium,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                              vertical: 8),
                                        ),
                                        onSubmitted: (value) => viewModel
                                            .setQuantity(line.productId,
                                                int.tryParse(value) ?? 0),
                                        onTapOutside: (_) {},
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

class _ProductPlaceholder extends StatelessWidget {
  const _ProductPlaceholder({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(Icons.inventory_2_outlined,
          size: 18, color: theme.colorScheme.onSurfaceVariant),
    );
  }
}
