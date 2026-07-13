import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/finance.dart';
import '../../../../data/repositories/finance_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/rupiah_field.dart';
import '../view_models/finance_form_view_model.dart';

class FinanceNewView extends StatelessWidget {
  const FinanceNewView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => FinanceFormViewModel(
        financeRepository: context.read<FinanceRepository>(),
      ),
      child: const _FinanceNewScreen(),
    );
  }
}

class _FinanceNewScreen extends StatefulWidget {
  const _FinanceNewScreen();

  @override
  State<_FinanceNewScreen> createState() => _FinanceNewScreenState();
}

class _FinanceNewScreenState extends State<_FinanceNewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _type = 'expense';
  String? _category;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _switchType(String type) {
    if (_type == type) return;
    setState(() {
      _type = type;
      _category = null;
    });
  }

  Future<void> _submit(AppLocalizations l10n) async {
    final category = _category;
    if (category == null || !_formKey.currentState!.validate()) return;
    final viewModel = context.read<FinanceFormViewModel>();
    final entry = await viewModel.submit(
      type: _type,
      amount: parseRupiahInput(_amountController.text),
      category: category,
      note: _noteController.text.trim(),
    );
    if (entry != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.financeSaved)),
      );
      context.go('/finance');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final viewModel = context.watch<FinanceFormViewModel>();
    final isExpense = _type == 'expense';
    final accent = isExpense ? theme.colorScheme.primary : theme.colorScheme.success;
    final categories = isExpense ? kExpenseCategories : kIncomeCategories;

    return Scaffold(
      appBar: AppBar(
        title: Text(isExpense
            ? l10n.financeNewExpenseTitle
            : l10n.financeNewIncomeTitle),
        leading: BackButton(onPressed: () => context.go('/finance')),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                      value: 'expense', label: Text(l10n.financeTypeExpense)),
                  ButtonSegment(
                      value: 'income', label: Text(l10n.financeTypeIncome)),
                ],
                selected: {_type},
                onSelectionChanged: (selection) => _switchType(selection.first),
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
              RupiahField(
                controller: _amountController,
                label: l10n.financeAmountLabel,
                autofocus: true,
                validator: (value) => parseRupiahInput(value ?? '') <= 0
                    ? l10n.financeAmountRequired
                    : null,
              ),
              const SizedBox(height: 16),
              Text(l10n.financeCategoryLabel, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final cat in categories)
                    ChoiceChip(
                      label: Text(cat),
                      selected: _category == cat,
                      selectedColor: accent.withValues(alpha: 0.15),
                      onSelected: (_) => setState(() => _category = cat),
                    ),
                ],
              ),
              if (_category == null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(l10n.financeCategoryRequired,
                      style: theme.textTheme.bodySmall!
                          .copyWith(color: theme.colorScheme.error)),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.financeNoteLabel,
                  hintText: l10n.financeNoteHint,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: accent),
                onPressed: viewModel.saving ? null : () => _submit(l10n),
                child: viewModel.saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isExpense ? l10n.financeSaveExpense : l10n.financeSaveIncome),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
