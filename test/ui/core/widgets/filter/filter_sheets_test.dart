import 'package:berdikari_mobile/l10n/generated/app_localizations.dart';
import 'package:berdikari_mobile/ui/core/theme/app_theme.dart';
import 'package:berdikari_mobile/ui/core/widgets/filter/date_range_filter_sheet.dart';
import 'package:berdikari_mobile/ui/core/widgets/filter/filter_chips_bar.dart';
import 'package:berdikari_mobile/ui/core/widgets/filter/filter_sheet_shell.dart';
import 'package:berdikari_mobile/ui/core/widgets/filter/option_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reusable filter system (chips → modal bottom sheet) — GoPay Riwayat
/// Transaksi-inspired, wired into Keuangan first. These tests exercise the
/// primitives directly (no repositories/network) so they cover the
/// interaction contract every future ERP module consumer relies on: state
/// preservation across opens, Hapus clearing the draft, and Pasang filter
/// committing it.
Widget _harness(Widget child) => MaterialApp(
      theme: AppTheme.light,
      supportedLocales: const [Locale('id')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('single-select sheet: shows drag handle, preserves selection, Hapus clears',
      (tester) async {
    String? applied;

    await tester.pumpWidget(_harness(
      Builder(
        builder: (context) => FilterChipsBar(chips: [
          FilterChipData(
            label: 'Jenis',
            isActive: applied != null,
            onTap: () async {
              final result = await showSingleSelectFilterSheet<String>(
                context: context,
                title: 'Jenis',
                selected: applied ?? '',
                clearValue: '',
                options: const [
                  FilterOption(value: '', label: 'Semua'),
                  FilterOption(value: 'income', label: 'Pemasukan'),
                  FilterOption(value: 'expense', label: 'Pengeluaran'),
                ],
              );
              if (result != null) applied = result;
            },
          ),
        ]),
      ),
    ));

    await tester.tap(find.text('Jenis'));
    await tester.pumpAndSettle();

    // Chrome: drag handle + title + Hapus + sticky Pasang filter.
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.showDragHandle, isTrue);
    expect(find.text('Hapus'), findsOneWidget);
    expect(find.text('Pasang filter'), findsOneWidget);

    await tester.tap(find.text('Pengeluaran'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pasang filter'));
    await tester.pumpAndSettle();

    expect(applied, 'expense');

    // Reopen: the sheet must reflect the previously applied value, not reset
    // — exactly one option is pre-selected (the one applied last time).
    await tester.tap(find.text('Jenis'));
    await tester.pumpAndSettle();
    final indicators = tester.widgetList<FilterRadioIndicator>(
        find.byType(FilterRadioIndicator));
    expect(indicators.where((i) => i.selected).length, 1);

    // Hapus clears the draft without closing the sheet.
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Pasang filter'), findsOneWidget); // still open

    await tester.tap(find.text('Pasang filter'));
    await tester.pumpAndSettle();
    expect(applied, ''); // cleared then applied
  });

  testWidgets('multi-select sheet toggles checkboxes and returns the applied set',
      (tester) async {
    Set<String>? applied;

    await tester.pumpWidget(_harness(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            final result = await showMultiSelectFilterSheet<String>(
              context: context,
              title: 'Metode',
              selected: const {},
              options: const [
                FilterOption(value: 'cash', label: 'Tunai'),
                FilterOption(value: 'saldo', label: 'GoPay Saldo'),
              ],
            );
            if (result != null) applied = result;
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pasang filter'));
    await tester.pumpAndSettle();

    expect(applied, {'cash'});
  });

  testWidgets('date-range sheet: picking a custom date selects the custom preset',
      (tester) async {
    DateRangeFilterResult? applied;

    await tester.pumpWidget(_harness(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            final result = await showDateRangeFilterSheet(
              context: context,
              title: 'Periode',
              presets: const [
                DateRangePresetOption(id: 'all', label: 'Semua'),
                DateRangePresetOption(id: 'custom', label: 'Kustom'),
              ],
              customPresetId: 'custom',
              selectedPresetId: 'all',
              customFromLabel: 'Dari',
              customToLabel: 'Sampai',
              customPickDateLabel: 'Pilih tanggal',
            );
            applied = result;
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(
        find.ancestor(of: find.text('Dari'), matching: find.byType(InkWell)).first);
    await tester.pumpAndSettle();
    // Material date picker opens; confirm today's date via the "OKE" action
    // (Indonesian MaterialLocalizations.okButtonLabel).
    await tester.tap(find.text('OKE'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pasang filter'));
    await tester.pumpAndSettle();

    expect(applied?.presetId, 'custom');
    expect(applied?.from, isNotNull);
  });
}
