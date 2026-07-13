/// Rupiah amounts arrive from the API as `int`, `double`, or decimal
/// strings ("15000.00"). Rupiah has no cents — normalize to `int`.
int parseRupiah(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.round();
  return num.tryParse(value.toString())?.round() ?? 0;
}

DateTime? parseDate(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;
