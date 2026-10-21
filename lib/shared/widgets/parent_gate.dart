import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import 'pill_button.dart';

/// "Ask a grown-up" check before parent mode: a multiplication young
/// children can't easily answer. Returns true when answered correctly.
class ParentGate extends StatefulWidget {
  const ParentGate({super.key, this.random});

  final Random? random;

  static Future<bool> show(BuildContext context, {Random? random}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ParentGate(random: random),
    );
    return ok ?? false;
  }

  @override
  State<ParentGate> createState() => _ParentGateState();
}

class _ParentGateState extends State<ParentGate> {
  late final Random _random = widget.random ?? Random();
  final TextEditingController _answer = TextEditingController();
  late int _a;
  late int _b;
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    _newQuestion();
  }

  void _newQuestion() {
    _a = 3 + _random.nextInt(7); // 3–9
    _b = 3 + _random.nextInt(7);
  }

  void _submit() {
    if (int.tryParse(_answer.text.trim()) == _a * _b) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _wrong = true;
      _answer.clear();
      _newQuestion();
    });
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusXL)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.gapXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, size: 40, color: AppColors.primary),
              const SizedBox(height: AppDimens.gapM),
              Text('Grown-ups only', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppDimens.gapS),
              Text(
                'To edit stories, answer:',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
              ),
              const SizedBox(height: AppDimens.gapM),
              Text(
                'What is $_a × $_b?',
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppDimens.gapM),
              TextField(
                controller: _answer,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Answer',
                  errorText: _wrong ? 'Not quite. Try this one.' : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimens.radiusM)),
                ),
              ),
              const SizedBox(height: AppDimens.gapL),
              Row(
                children: [
                  Expanded(
                    child: PillButton(
                      label: 'Cancel',
                      variant: PillButtonVariant.soft,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: AppDimens.gapM),
                  Expanded(
                    child: PillButton(label: 'Unlock', leadingIcon: Icons.lock_open_rounded, onPressed: _submit),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
