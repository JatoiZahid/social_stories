import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../features/account/account_screen.dart';
import 'parent_gate.dart';

/// Reading preferences, opened from the gear icon on any screen.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppDimens.gapXL, 0, AppDimens.gapXL, AppDimens.gapXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppDimens.gapS),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Read pages aloud'),
              subtitle: const Text('Each page is read when it opens'),
              value: settings.autoRead,
              onChanged: (value) => settings.autoRead = value,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Large text'),
              value: settings.largeText,
              onChanged: (value) => settings.largeText = value,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.manage_accounts_rounded, color: AppColors.primary),
              title: const Text('Account & story editing'),
              subtitle: const Text('For grown-ups: subscription, editing stories and quiz questions'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final navigator = Navigator.of(context);
                final unlocked = await ParentGate.show(context);
                if (!unlocked) return;
                navigator
                  ..pop() // close the sheet
                  ..push(AccountScreen.route());
              },
            ),
            const SizedBox(height: AppDimens.gapS),
            Text('Reading speed', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            Row(
              children: [
                const Icon(Icons.slow_motion_video_rounded, color: AppColors.inkSoft),
                Expanded(
                  child: Slider(
                    value: settings.speechRate,
                    min: AppSettings.minSpeechRate,
                    max: AppSettings.maxSpeechRate,
                    divisions: 4,
                    label: _speedLabel(settings.speechRate),
                    onChanged: (value) => settings.speechRate = value,
                  ),
                ),
                const Icon(Icons.speed_rounded, color: AppColors.inkSoft),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _speedLabel(double rate) {
    if (rate < 0.3) return 'Very slow';
    if (rate < 0.4) return 'Slow';
    if (rate < 0.5) return 'Normal';
    return 'Fast';
  }
}
