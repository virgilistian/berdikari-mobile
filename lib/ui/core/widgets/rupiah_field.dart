import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';

/// Live thousand-separator formatter for Rupiah input — the mobile
/// counterpart of the web's `useRupiahInput` composable.
class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final formatted = formatRupiahDigits(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Parses the display text of a Rupiah field back to whole Rupiah.
int parseRupiahInput(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? 0 : int.parse(digits);
}

/// Numeric text field with "Rp" prefix and live thousand separators.
class RupiahField extends StatelessWidget {
  const RupiahField({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
    this.validator,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final String? Function(String?)? validator;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [RupiahInputFormatter()],
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'Rp ',
        errorText: errorText,
      ),
      validator: validator,
    );
  }
}
