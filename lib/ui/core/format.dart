import 'package:intl/intl.dart';

final NumberFormat _rupiah = NumberFormat.decimalPattern('id');

/// "Rp15.000" — same style the web app renders. Mirrors `utils.ts`.
String formatRupiah(int amount) {
  final sign = amount < 0 ? '-' : '';
  return '${sign}Rp${_rupiah.format(amount.abs())}';
}

/// "15.000" without the currency prefix, for input fields.
String formatRupiahDigits(int amount) => _rupiah.format(amount);
