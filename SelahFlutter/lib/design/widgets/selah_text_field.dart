import 'package:flutter/material.dart';

import '../selah_typography.dart';

/// Selah 标准输入框（带标签与错误位）。
class SelahTextField extends StatelessWidget {
  const SelahTextField({
    super.key,
    required this.controller,
    this.hint,
    this.label,
    this.errorText,
    this.maxLines = 1,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? hint;
  final String? label;
  final String? errorText;
  final int maxLines;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: SelahTypography.bodyLarge(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}
