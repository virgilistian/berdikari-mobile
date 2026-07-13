import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/order.dart';
import '../../../../data/repositories/cart_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';
import 'payment_sheet.dart';

/// Cart line editor. Pops with the completed [Order] after checkout so the
/// POS screen can show the receipt.
class CartSheet extends StatelessWidget {
  const CartSheet({super.key});

  Future<void> _startPayment(BuildContext context) async {
    final cart = context.read<CartRepository>();
    final order = await showModalBottomSheet<Order>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChangeNotifierProvider<CartRepository>.value(
        value: cart,
        child: const PaymentSheet(),
      ),
    );
    if (order != null && context.mounted) {
      Navigator.of(context).pop(order);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cart = context.watch<CartRepository>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.cartTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (cart.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.cartEmpty,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in cart.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name,
                                      style: theme.textTheme.titleSmall),
                                  Text(
                                    formatRupiah(item.unitPrice),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              constraints: const BoxConstraints(
                                  minWidth: 44, minHeight: 44),
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => cart.decrease(item.productId),
                            ),
                            Text('${item.quantity}',
                                style: theme.textTheme.titleSmall),
                            IconButton(
                              constraints: const BoxConstraints(
                                  minWidth: 44, minHeight: 44),
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => cart.increase(item.productId),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.totalLabel, style: theme.textTheme.bodyMedium),
                Text(
                  formatRupiah(cart.totalAmount),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: cart.isEmpty ? null : () => _startPayment(context),
              child: Text(l10n.payButton),
            ),
          ],
        ),
      ),
    );
  }
}
