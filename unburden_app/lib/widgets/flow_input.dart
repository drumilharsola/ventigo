import 'package:flutter/material.dart';
import '../config/theme.dart';

class FlowInput extends StatelessWidget {
  final String? label;
  final String? placeholder;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final int maxLines;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;

  const FlowInput({
    super.key,
    this.label,
    this.placeholder,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.maxLines = 1,
    this.autofillHints,
    this.textInputAction,
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
            style: AppTypography.label(color: AppColors.ink),
          ),
          const SizedBox(height: 8),
        ],
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadii.mdAll,
            boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 8))],
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            autofocus: autofocus,
            maxLines: maxLines,
            autofillHints: autofillHints,
            textInputAction: textInputAction,
            style: AppTypography.ui(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.ink),
            cursorColor: AppColors.accent,
            decoration: InputDecoration(
              hintText: placeholder,
            ),
          ),
        ),
      ],
    );
  }
}
