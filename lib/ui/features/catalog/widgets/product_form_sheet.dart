import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/product.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/format.dart';
import '../../../core/widgets/rupiah_field.dart';
import '../view_models/product_form_view_model.dart';

/// Opens the create/edit product bottom sheet. Returns true if the caller
/// should refresh its product list (any save or delete).
Future<bool> showProductFormSheet(
  BuildContext context, {
  required List<ProductCategory> categories,
  Product? product,
}) async {
  final catalog = context.read<CatalogRepository>();
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ChangeNotifierProvider(
      create: (_) => ProductFormViewModel(
        catalogRepository: catalog,
        existing: product,
      ),
      child: ProductFormSheet(categories: categories),
    ),
  );
  return result ?? false;
}

class ProductFormSheet extends StatefulWidget {
  const ProductFormSheet({super.key, required this.categories});

  final List<ProductCategory> categories;

  @override
  State<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _costController;
  late String? _categoryId;
  late bool _isActive;
  late List<ProductCategory> _categories;
  bool _showAddCategory = false;
  final _newCategoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = context.read<ProductFormViewModel>().editing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _priceController = TextEditingController(
        text: existing == null ? '' : formatRupiahDigits(existing.price));
    _costController = TextEditingController(
        text: existing == null ? '' : formatRupiahDigits(existing.costPrice));
    _categoryId = existing?.categoryId;
    _isActive = existing?.isActive ?? true;
    _categories = List.of(widget.categories);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _addCategory(ProductFormViewModel viewModel) async {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) return;
    final category = await viewModel.createCategory(name);
    if (category != null && mounted) {
      setState(() {
        _categories = [..._categories, category];
        _categoryId = category.id;
        _showAddCategory = false;
        _newCategoryController.clear();
      });
    }
  }

  Future<void> _submit(ProductFormViewModel viewModel) async {
    if (!_formKey.currentState!.validate()) return;
    final product = await viewModel.submit(
      name: _nameController.text.trim(),
      categoryId: _categoryId,
      price: parseRupiahInput(_priceController.text),
      costPrice: parseRupiahInput(_costController.text),
      isActive: _isActive,
    );
    if (product != null && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete(ProductFormViewModel viewModel) async {
    final l10n = AppLocalizations.of(context)!;
    final name = viewModel.editing!.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteProductConfirmTitle),
        content: Text(l10n.deleteProductConfirmMessage(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await viewModel.delete();
    if (success && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final viewModel = context.watch<ProductFormViewModel>();
    final isEditing = viewModel.editing != null;
    final margin = parseRupiahInput(_priceController.text) -
        parseRupiahInput(_costController.text);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEditing ? l10n.editProduct : l10n.newProduct,
                  style: theme.textTheme.titleMedium,
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
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.productNameLabel,
                    hintText: l10n.productNameHint,
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.nameRequired
                      : null,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.categoryLabel, style: theme.textTheme.bodySmall),
                    if (!_showAddCategory)
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _showAddCategory = true),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(l10n.createNewCategory),
                      ),
                  ],
                ),
                DropdownButtonFormField<String?>(
                  initialValue: _categoryId,
                  items: [
                    DropdownMenuItem(
                        value: null, child: Text(l10n.noCategoryOption)),
                    for (final category in _categories)
                      DropdownMenuItem(
                          value: category.id, child: Text(category.name)),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
                if (_showAddCategory) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newCategoryController,
                          decoration:
                              InputDecoration(hintText: l10n.newCategoryHint),
                        ),
                      ),
                      IconButton(
                        onPressed: viewModel.savingCategory
                            ? null
                            : () => _addCategory(viewModel),
                        icon: viewModel.savingCategory
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                      ),
                      IconButton(
                        onPressed: () => setState(() {
                          _showAddCategory = false;
                          _newCategoryController.clear();
                        }),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                RupiahField(
                  controller: _priceController,
                  label: l10n.sellPriceLabel,
                  validator: (value) => (value == null || value.isEmpty)
                      ? l10n.sellPriceRequired
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(l10n.sellPriceHint,
                      style: theme.textTheme.bodySmall),
                ),
                const SizedBox(height: 16),
                RupiahField(
                  controller: _costController,
                  label: l10n.costPriceLabel,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(l10n.costPriceHint,
                      style: theme.textTheme.bodySmall),
                ),
                if (margin > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.marginEstimate(formatRupiah(margin)),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.productActiveLabel),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed:
                      viewModel.saving ? null : () => _submit(viewModel),
                  child: viewModel.saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.save),
                ),
                if (isEditing) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed:
                        viewModel.saving ? null : () => _delete(viewModel),
                    icon: Icon(Icons.delete_outline,
                        color: theme.colorScheme.error),
                    label: Text(
                      l10n.deleteProduct,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
