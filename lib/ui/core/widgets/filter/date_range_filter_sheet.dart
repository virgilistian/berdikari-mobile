import 'package:flutter/material.dart';

import '../../format.dart';
import 'filter_sheet_shell.dart';

/// One preset row in a [showDateRangeFilterSheet] (e.g. "Bulan Ini" with a
/// computed "1 Jul 2026 - 21 Jul 2026" subtitle). [subtitle] is precomputed
/// by the caller (display-only) — the sheet never derives date math itself,
/// since each module's period semantics differ (mirrors, but does not
/// replace, the owning store's own filtering logic).
class DateRangePresetOption {
  const DateRangePresetOption({required this.id, required this.label, this.subtitle});

  final String id;
  final String label;
  final String? subtitle;
}

/// Result of a date-range filter sheet: the chosen preset id, plus the
/// custom from/to dates (only meaningful when [presetId] == the sheet's
/// `customPresetId`).
class DateRangeFilterResult {
  const DateRangeFilterResult({required this.presetId, this.from, this.to});

  final String presetId;
  final DateTime? from;
  final DateTime? to;
}

/// Opens a date-range filter sheet: a preset radio list followed by an
/// always-visible custom "Dari"/"Sampai" date-field row — mirrors GoPay's
/// "Pilih tanggal transaksi" sheet exactly. Picking a custom date implicitly
/// selects [customPresetId], same as tapping a date field in the reference.
Future<DateRangeFilterResult?> showDateRangeFilterSheet({
  required BuildContext context,
  required String title,
  required List<DateRangePresetOption> presets,
  required String customPresetId,
  required String selectedPresetId,
  required String customFromLabel,
  required String customToLabel,
  required String customPickDateLabel,
  DateTime? customFrom,
  DateTime? customTo,
}) {
  return showFilterModalSheet<DateRangeFilterResult>(
    context: context,
    builder: (_) => _DateRangeFilterSheetBody(
      title: title,
      presets: presets,
      customPresetId: customPresetId,
      initialPresetId: selectedPresetId,
      customFromLabel: customFromLabel,
      customToLabel: customToLabel,
      customPickDateLabel: customPickDateLabel,
      initialCustomFrom: customFrom,
      initialCustomTo: customTo,
    ),
  );
}

class _DateRangeFilterSheetBody extends StatefulWidget {
  const _DateRangeFilterSheetBody({
    required this.title,
    required this.presets,
    required this.customPresetId,
    required this.initialPresetId,
    required this.customFromLabel,
    required this.customToLabel,
    required this.customPickDateLabel,
    this.initialCustomFrom,
    this.initialCustomTo,
  });

  final String title;
  final List<DateRangePresetOption> presets;
  final String customPresetId;
  final String initialPresetId;
  final String customFromLabel;
  final String customToLabel;
  final String customPickDateLabel;
  final DateTime? initialCustomFrom;
  final DateTime? initialCustomTo;

  @override
  State<_DateRangeFilterSheetBody> createState() => _DateRangeFilterSheetBodyState();
}

class _DateRangeFilterSheetBodyState extends State<_DateRangeFilterSheetBody> {
  late String _presetId;
  DateTime? _customFrom;
  DateTime? _customTo;

  @override
  void initState() {
    super.initState();
    _presetId = widget.initialPresetId;
    _customFrom = widget.initialCustomFrom;
    _customTo = widget.initialCustomTo;
  }

  Future<void> _pickCustomDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = (isFrom ? _customFrom : _customTo) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _customFrom = picked;
      } else {
        _customTo = picked;
      }
      _presetId = widget.customPresetId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FilterSheetShell(
      title: widget.title,
      onClear: () => setState(() {
        _presetId = widget.presets.first.id;
        _customFrom = null;
        _customTo = null;
      }),
      onApply: () => Navigator.of(context).pop(
        DateRangeFilterResult(presetId: _presetId, from: _customFrom, to: _customTo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final preset in widget.presets)
            _PresetTile(
              option: preset,
              selected: _presetId == preset.id,
              onTap: () => setState(() => _presetId = preset.id),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _CustomDateField(
                    label: widget.customFromLabel,
                    date: _customFrom,
                    placeholder: widget.customPickDateLabel,
                    onTap: () => _pickCustomDate(isFrom: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CustomDateField(
                    label: widget.customToLabel,
                    date: _customTo,
                    placeholder: widget.customPickDateLabel,
                    onTap: () => _pickCustomDate(isFrom: false),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.option, required this.selected, required this.onTap});

  final DateRangePresetOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.label, style: theme.textTheme.bodyMedium),
                  if (option.subtitle != null)
                    Text(option.subtitle!, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            FilterRadioIndicator(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _CustomDateField extends StatelessWidget {
  const _CustomDateField({
    required this.label,
    required this.date,
    required this.placeholder,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(date == null ? placeholder : formatShortDate(date!)),
      ),
    );
  }
}
