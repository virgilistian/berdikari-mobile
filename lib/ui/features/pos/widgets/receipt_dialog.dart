import 'package:flutter/material.dart';

import '../../../../data/models/order.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';

/// Post-checkout receipt: order number, total, paid, change.
Future<void> showReceiptDialog(BuildContext context, Order order) {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);

  Widget row(String label, String value, {TextStyle? valueStyle}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Text(value, style: valueStyle ?? theme.textTheme.titleSmall),
          ],
        ),
      );

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(
        Icons.check_circle_outline,
        color: theme.colorScheme.primary,
        size: 40,
      ),
      title: Text(l10n.receiptSuccess),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (order.orderNo != null)
            Text(order.orderNo!, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          row(l10n.totalLabel, formatRupiah(order.totalAmount)),
          row(l10n.paidLabel, formatRupiah(order.paidAmount)),
          row(
            l10n.changeLabel,
            formatRupiah(order.changeAmount),
            valueStyle: theme.textTheme.titleSmall!
                .copyWith(color: theme.colorScheme.primary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.newTransaction),
        ),
      ],
    ),
  );
}
