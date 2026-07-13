import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/stock.dart';
import '../../../../data/repositories/stock_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../view_models/stock_action_view_model.dart';

/// Opens the Terima/Sesuaikan bottom sheet for one product. Returns true
/// if the caller should refresh the stock list.
Future<bool> showStockActionSheet(
  BuildContext context, {
  required StockActionType type,
  required StockRow row,
}) async {
  final repo = context.read<StockRepository>();
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ChangeNotifierProvider(
      create: (_) => StockActionViewModel(stockRepository: repo),
      child: StockActionSheet(type: type, row: row),
    ),
  );
  return result ?? false;
}

class StockActionSheet extends StatefulWidget {
  const StockActionSheet({super.key, required this.type, required this.row});

  final StockActionType type;
  final StockRow row;

  @override
  State<StockActionSheet> createState() => _StockActionSheetState();
}

class _StockActionSheetState extends State<StockActionSheet> {
  late final TextEditingController _qtyController;
  late final TextEditingController _minController;
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final isAdjust = widget.type == StockActionType.adjust;
    _qtyController =
        TextEditingController(text: isAdjust ? '${widget.row.quantity}' : '');
    _minController = TextEditingController(text: '${widget.row.minStock}');
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _minController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit(StockActionViewModel viewModel) async {
    final quantity = int.tryParse(_qtyController.text);
    if (quantity == null) return;
    final minStock = widget.type == StockActionType.adjust
        ? int.tryParse(_minController.text)
        : null;
    final success = await viewModel.submit(
      type: widget.type,
      productId: widget.row.productId,
      quantity: quantity,
      minStock: minStock,
      currentMinStock: widget.row.minStock,
      reason: _reasonController.text.trim(),
    );
    if (success && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final viewModel = context.watch<StockActionViewModel>();
    final isReceive = widget.type == StockActionType.receive;
    final quantity = int.tryParse(_qtyController.text);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isReceive ? l10n.receiveStockTitle : l10n.adjustStockTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.row.productName} — ${l10n.currentStockOf(widget.row.quantity)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (viewModel.errorMessage != null) ...[
              Text(
                viewModel.errorMessage!,
                style: theme.textTheme.bodyMedium!
                    .copyWith(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText:
                    isReceive ? l10n.incomingQtyLabel : l10n.actualQtyLabel,
              ),
            ),
            if (!isReceive) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _minController,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: l10n.minStockThresholdLabel),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: l10n.reasonOptionalLabel,
                hintText:
                    isReceive ? l10n.reasonReceiveHint : l10n.reasonAdjustHint,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: (viewModel.submitting || quantity == null)
                  ? null
                  : () => _submit(viewModel),
              child: viewModel.submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
