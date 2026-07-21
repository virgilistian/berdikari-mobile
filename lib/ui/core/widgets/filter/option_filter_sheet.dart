import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import 'filter_sheet_shell.dart';

/// One selectable row inside a [showSingleSelectFilterSheet] /
/// [showMultiSelectFilterSheet] option list.
class FilterOption<T> {
  const FilterOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;

  /// Optional leading icon (rendered in a tinted circle, GoPay-style). Null
  /// renders a plain text row — most Berdikari filters (periode, kategori)
  /// don't need one.
  final IconData? icon;
}

/// Opens a single-select (radio) filter sheet. Returns the newly applied
/// value on "Pasang filter", or null if the sheet was dismissed without
/// applying (back gesture / tap outside) — distinct from "Hapus" then
/// "Pasang filter", which applies [clearValue] (e.g. `''` for an "all"
/// option). [selected] seeds the sheet with the currently-applied value so
/// state is preserved across opens.
Future<T?> showSingleSelectFilterSheet<T>({
  required BuildContext context,
  required String title,
  required List<FilterOption<T>> options,
  required T selected,
  T? clearValue,
  bool searchable = false,
}) {
  return showFilterModalSheet<T>(
    context: context,
    builder: (_) => _OptionFilterSheetBody<T>(
      title: title,
      options: options,
      searchable: searchable,
      initialSingle: selected,
      clearValue: clearValue,
    ),
  );
}

/// Opens a multi-select (checkbox) filter sheet — mirrors GoPay's payment
/// method sheet. Returns the newly applied set on "Pasang filter", or null
/// if dismissed without applying.
Future<Set<T>?> showMultiSelectFilterSheet<T>({
  required BuildContext context,
  required String title,
  required List<FilterOption<T>> options,
  required Set<T> selected,
  bool searchable = false,
}) {
  return showFilterModalSheet<Set<T>>(
    context: context,
    builder: (_) => _OptionFilterSheetBody<T>(
      title: title,
      options: options,
      searchable: searchable,
      initialMulti: selected,
    ),
  );
}

class _OptionFilterSheetBody<T> extends StatefulWidget {
  const _OptionFilterSheetBody({
    required this.title,
    required this.options,
    required this.searchable,
    this.initialSingle,
    this.initialMulti,
    this.clearValue,
  }) : multi = initialMulti != null;

  final String title;
  final List<FilterOption<T>> options;
  final bool searchable;
  final bool multi;
  final T? initialSingle;
  final Set<T>? initialMulti;

  /// What "Hapus" resets a single-select draft to (e.g. `''` for an "all"
  /// option). Irrelevant for multi-select, which always clears to `{}`.
  final T? clearValue;

  @override
  State<_OptionFilterSheetBody<T>> createState() => _OptionFilterSheetBodyState<T>();
}

class _OptionFilterSheetBodyState<T> extends State<_OptionFilterSheetBody<T>> {
  T? _draftSingle;
  Set<T> _draftMulti = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _draftSingle = widget.initialSingle;
    _draftMulti = {...?widget.initialMulti};
  }

  List<FilterOption<T>> get _visibleOptions {
    if (_query.isEmpty) return widget.options;
    final query = _query.toLowerCase();
    return widget.options.where((o) => o.label.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final options = _visibleOptions;

    return FilterSheetShell(
      title: widget.title,
      onClear: () => setState(() {
        _draftSingle = widget.clearValue;
        _draftMulti = {};
      }),
      onApply: () => Navigator.of(context).pop(widget.multi ? _draftMulti : _draftSingle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.searchable)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: TextField(
                decoration: InputDecoration(
                  hintText: l10n.filterSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
          if (options.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(l10n.filterNoResults, style: theme.textTheme.bodyMedium),
              ),
            )
          else
            for (final option in options)
              _OptionTile<T>(
                option: option,
                selected: widget.multi
                    ? _draftMulti.contains(option.value)
                    : _draftSingle == option.value,
                multi: widget.multi,
                onTap: () => setState(() {
                  if (widget.multi) {
                    if (_draftMulti.contains(option.value)) {
                      _draftMulti.remove(option.value);
                    } else {
                      _draftMulti.add(option.value);
                    }
                  } else {
                    _draftSingle = option.value;
                  }
                }),
              ),
        ],
      ),
    );
  }
}

class _OptionTile<T> extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selected,
    required this.multi,
    required this.onTap,
  });

  final FilterOption<T> option;
  final bool selected;
  final bool multi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(
          children: [
            if (option.icon != null) ...[
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(option.icon, size: 18, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(option.label, style: theme.textTheme.bodyMedium),
            ),
            SizedBox(
              width: 24,
              height: 24,
              child: multi
                  ? Checkbox(value: selected, onChanged: (_) => onTap())
                  : FilterRadioIndicator(selected: selected),
            ),
          ],
        ),
      ),
    );
  }
}
