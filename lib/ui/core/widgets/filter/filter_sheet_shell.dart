import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';

/// Opens a filter modal bottom sheet with the shared chrome (drag handle,
/// rounded top, scroll-controlled so it can grow with content up to the
/// keyboard). Every `show*FilterSheet` helper in this package calls this —
/// it is the one place the sheet's shape/behavior is defined, so all filter
/// sheets across every ERP module look and animate the same.
Future<T?> showFilterModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)), // sheet-role radius
    ),
    builder: builder,
  );
}

/// Shared chrome for every filter sheet: title + optional "Hapus" (clear)
/// button, a scrollable body, and a sticky full-width "Pasang filter"
/// (apply) button — mirrors the GoPay Riwayat Transaksi filter sheets.
/// [child] is the option list; callers own its selection state and pass the
/// current draft in, so Hapus/Pasang filter just mutate that draft.
class FilterSheetShell extends StatelessWidget {
  const FilterSheetShell({
    super.key,
    required this.title,
    required this.onApply,
    required this.child,
    this.onClear,
  });

  final String title;
  final VoidCallback? onClear;
  final VoidCallback onApply;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleLarge),
                ),
                if (onClear != null)
                  TextButton(
                    onPressed: onClear,
                    style: TextButton.styleFrom(
                      shape: StadiumBorder(
                        side: BorderSide(color: theme.colorScheme.outline),
                      ),
                      minimumSize: const Size(0, kMinTapTarget),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      foregroundColor: theme.colorScheme.onSurface,
                    ),
                    child: Text(l10n.filterClearAction),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: child,
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: SizedBox(
              width: double.infinity,
              height: kMinTapTarget,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
                onPressed: onApply,
                child: Text(l10n.filterApplyAction),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single-select indicator for filter option/preset rows — a plain themed
/// circle rather than [Radio], since these rows already drive selection via
/// their own `onTap` (no need for Flutter's `RadioGroup` wiring).
class FilterRadioIndicator extends StatelessWidget {
  const FilterRadioIndicator({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
          width: 1.5,
        ),
      ),
      child: selected
          ? Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary,
              ),
            )
          : null,
    );
  }
}
