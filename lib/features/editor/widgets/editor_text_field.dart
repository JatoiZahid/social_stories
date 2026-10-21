import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';

/// Rounded, tinted text field used across the editors.
class EditorTextField extends StatelessWidget {
  const EditorTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
    this.hint,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.sentences,
    this.bold = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusM),
          borderSide: BorderSide(color: color, width: width),
        );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      minLines: 1,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: bold ? AppColors.ink : AppColors.inkSoft,
          ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.tint,
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.primary, 2),
      ),
    );
  }
}

/// Small bold heading above an editor section.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.gapS),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
