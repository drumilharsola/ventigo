import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Styled text field — maps .flow-input from globals.css.
class FlowInput extends StatelessWidget {
  final String? label;
  final String? placeholder;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final int maxLines;

  const FlowInput({
    super.key,
    this.label,
    this.placeholder,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.autofocus = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!.toUpperCase(),
            style: AppTypography.label(),
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          autofocus: autofocus,
          maxLines: maxLines,
          style: AppTypography.ui(fontSize: 14, color: AppColors.white),
          cursorColor: AppColors.accent,
          decoration: InputDecoration(
            hintText: placeholder,
            // Theme provides the rest via inputDecorationTheme.
          ),
        ),
      ],
    );
  }
}
