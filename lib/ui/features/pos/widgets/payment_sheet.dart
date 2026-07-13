import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/cart_repository.dart';
import '../../../../data/services/api_client.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';
import '../../../core/widgets/rupiah_field.dart';

/// Payment step: method + amount tendered. Pops with the completed order.
/// Non-cash methods (QRIS/transfer) always pay the exact total.
class PaymentSheet extends StatefulWidget {
  const PaymentSheet({super.key});

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  final _cashController = TextEditingController();
  final _customerController = TextEditingController();
  String _method = 'cash';
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final total = context.read<CartRepository>().totalAmount;
    _cashController.text = formatRupiahDigits(total);
  }

  @override
  void dispose() {
    _cashController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final cart = context.read<CartRepository>();
    final total = cart.totalAmount;
    final tendered =
        _method == 'cash' ? parseRupiahInput(_cashController.text) : total;

    if (tendered < total) {
      setState(() => _error = l10n.cashInsufficient);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final order = await cart.checkout(
        payment: tendered,
        method: _method,
        customerName: _customerController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(order);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = l10n.genericError);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final total = context.watch<CartRepository>().totalAmount;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.paymentTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.totalLabel, style: theme.textTheme.bodyMedium),
                Text(formatRupiah(total),
                    style: theme.textTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.paymentMethodLabel, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'cash', label: Text(l10n.methodCash)),
                ButtonSegment(value: 'qris', label: Text(l10n.methodQris)),
                ButtonSegment(
                    value: 'transfer', label: Text(l10n.methodTransfer)),
              ],
              selected: {_method},
              onSelectionChanged: (selection) =>
                  setState(() => _method = selection.first),
            ),
            const SizedBox(height: 16),
            if (_method == 'cash') ...[
              RupiahField(
                controller: _cashController,
                label: l10n.cashReceivedLabel,
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _customerController,
              decoration: InputDecoration(labelText: l10n.customerNameLabel),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium!
                    .copyWith(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.processPayment),
            ),
          ],
        ),
      ),
    );
  }
}
