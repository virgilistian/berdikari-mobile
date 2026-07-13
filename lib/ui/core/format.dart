import 'package:intl/intl.dart';

final NumberFormat _rupiah = NumberFormat.decimalPattern('id');

/// "Rp15.000" — same style the web app renders. Mirrors `utils.ts`.
String formatRupiah(int amount) {
  final sign = amount < 0 ? '-' : '';
  return '${sign}Rp${_rupiah.format(amount.abs())}';
}

/// "15.000" without the currency prefix, for input fields.
String formatRupiahDigits(int amount) => _rupiah.format(amount);

const _indonesianWeekdays = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  "Jum'at",
  'Sabtu',
  'Minggu',
];

const _indonesianMonths = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// "Senin, 13 Juli 2026" — spelled out manually rather than via
/// `DateFormat(pattern, 'id')`, which needs `initializeDateFormatting()`
/// to load locale data the app doesn't otherwise need.
String formatIndonesianDate(DateTime date) {
  final weekday = _indonesianWeekdays[date.weekday - 1];
  final month = _indonesianMonths[date.month - 1];
  return '$weekday, ${date.day} $month ${date.year}';
}
