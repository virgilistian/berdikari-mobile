import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/finance.dart';
import '../../../../data/repositories/finance_repository.dart';
import '../../../../data/services/api_client.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';
import '../../../core/widgets/rupiah_field.dart';

/// Out-of-till operational expense recorded against the active shift
/// (`pos.expense`) — mirrors berdikari-web `pos/index.vue`'s "Catat
/// Pengeluaran" drawer.
class ExpenseSheet extends StatefulWidget {
  const ExpenseSheet({super.key, required this.shiftId});

  final String shiftId;

  @override
  State<ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<ExpenseSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _category;
  bool _submitting = false;
  String? _error;
  List<FinanceEntry> _shiftExpenses = [];
  bool _loadingExpenses = true;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
    context
        .read<FinanceRepository>()
        .fetchShiftExpenses(widget.shiftId)
        .then((expenses) {
      if (mounted) {
        setState(() {
          _shiftExpenses = expenses;
          _loadingExpenses = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _loadingExpenses = false);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final category = _category;
    final amount = parseRupiahInput(_amountController.text);
    if (category == null || amount <= 0) return;

    final financeRepo = context.read<FinanceRepository>();
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await financeRepo.createShiftExpense(
        shiftId: widget.shiftId,
        amount: amount,
        category: category,
        note: _noteController.text.trim(),
      );
      final expenses = await financeRepo.fetchShiftExpenses(widget.shiftId);
      if (!mounted) return;
      setState(() {
        _shiftExpenses = expenses;
        _amountController.clear();
        _noteController.clear();
        _category = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.posExpenseSaved)),
      );
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

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.posExpenseDrawerTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              RupiahField(
                controller: _amountController,
                label: l10n.posExpenseAmountLabel,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Text(l10n.posExpenseCategoryLabel, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final cat in kExpenseCategories)
                    ChoiceChip(
                      label: Text(cat),
                      selected: _category == cat,
                      onSelected: (_) => setState(() => _category = cat),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(labelText: l10n.posExpenseNoteLabel),
              ),
              if (!_loadingExpenses && _shiftExpenses.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.posExpenseRecordedTitle, style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                for (final e in _shiftExpenses)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text(e.category,
                                style: theme.textTheme.bodyMedium)),
                        Text(formatRupiah(e.amount),
                            style: theme.textTheme.bodyMedium!
                                .copyWith(color: theme.colorScheme.error)),
                      ],
                    ),
                  ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: theme.textTheme.bodyMedium!
                        .copyWith(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: (_submitting ||
                        _category == null ||
                        parseRupiahInput(_amountController.text) <= 0)
                    ? null
                    : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
