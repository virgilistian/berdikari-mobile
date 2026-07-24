import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/finance.dart';
import '../../../../data/repositories/finance_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/rupiah_field.dart';
import '../view_models/finance_form_view_model.dart';

/// Create/edit cash entry form. `entry == null` creates a new one (mirrors
/// berdikari-web `finance/new.vue`); `entry` set edits it in place (mirrors
/// `finance/[id].vue`) — only manual entries reach this screen, the list
/// never offers editing for auto (POS-generated) ones.
class FinanceFormView extends StatelessWidget {
  const FinanceFormView({super.key, this.entry});

  final FinanceEntry? entry;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => FinanceFormViewModel(
        financeRepository: context.read<FinanceRepository>(),
        existing: entry,
      ),
      child: _FinanceFormScreen(entry: entry),
    );
  }
}

class _FinanceFormScreen extends StatefulWidget {
  const _FinanceFormScreen({this.entry});

  final FinanceEntry? entry;

  @override
  State<_FinanceFormScreen> createState() => _FinanceFormScreenState();
}

class _FinanceFormScreenState extends State<_FinanceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _type = 'expense';
  String? _category;
  DateTime _occurredAt = DateTime.now();

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    if (entry != null) {
      _amountController.text = formatRupiahDigits(entry.amount);
      _noteController.text = entry.note ?? '';
      _type = entry.type;
      _category = entry.category;
      _occurredAt = entry.occurredAt;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null) setState(() => _occurredAt = picked);
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
      occurredAt: _occurredAt,
    );
    if (entry != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? l10n.financeUpdated : l10n.financeSaved)),
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
        title: Text(_isEditing
            ? l10n.financeEditTitle
            : (isExpense ? l10n.financeNewExpenseTitle : l10n.financeNewIncomeTitle)),
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
                autofocus: !_isEditing,
                validator: (value) => parseRupiahInput(value ?? '') <= 0
                    ? l10n.financeAmountRequired
                    : null,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(labelText: l10n.financeDateLabel),
                  child: Text(formatIndonesianDate(_occurredAt)),
                ),
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
                    : Text(_isEditing
                        ? l10n.financeSaveChanges
                        : (isExpense ? l10n.financeSaveExpense : l10n.financeSaveIncome)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
