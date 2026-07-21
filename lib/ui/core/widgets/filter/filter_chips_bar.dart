import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// One chip in a [FilterChipsBar] — presentational only. The screen owning
/// the filter state decides [isActive]/[activeCount] and what [onTap] opens
/// (a `showSingleSelectFilterSheet` / `showMultiSelectFilterSheet` /
/// `showDateRangeFilterSheet` call, typically).
class FilterChipData {
  const FilterChipData({
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.activeCount = 0,
  });

  final String label;
  final VoidCallback onTap;
  final bool isActive;

  /// Number badge shown on the chip (e.g. "3" categories selected). 0 hides
  /// the badge — the filled/outlined chip state alone still communicates
  /// "active" for single-value filters.
  final int activeCount;
}

/// Horizontally scrollable row of filter chips — the entry point of the
/// reusable filter system (GoPay Riwayat Transaksi-style: chip row up top,
/// each chip opens its own modal sheet). Reused across ERP modules; only the
/// [chips] passed in are module-specific.
class FilterChipsBar extends StatelessWidget {
  const FilterChipsBar({super.key, required this.chips});

  final List<FilterChipData> chips;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kMinTapTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => _FilterChip(data: chips[index]),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.data});

  final FilterChipData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = data.isActive;
    final foreground = active ? theme.colorScheme.primary : theme.colorScheme.onSurface;

    return Material(
      color: active ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: active ? theme.colorScheme.primary : theme.colorScheme.outline,
          width: active ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: data.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: kMinTapTarget,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.label,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: foreground,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (data.activeCount > 0) ...[
                const SizedBox(width: 6),
                _CountBadge(count: data.activeCount),
              ] else ...[
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: foreground),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelSmall!.copyWith(
          color: theme.colorScheme.onPrimary,
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
