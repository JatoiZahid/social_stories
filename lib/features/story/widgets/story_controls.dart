import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/widgets.dart';

/// Replay, pause/resume, page progress and child-paced next/finish actions.
class StoryControls extends StatelessWidget {
  const StoryControls({
    super.key,
    required this.pageCount,
    required this.currentIndex,
    required this.onListenAgain,
    required this.onNext,
    this.onTogglePlayback,
    this.isPlaying = false,
    this.isPaused = false,
  });

  final int pageCount;
  final int currentIndex;
  final VoidCallback onListenAgain;
  final VoidCallback onNext;
  final VoidCallback? onTogglePlayback;
  final bool isPlaying;
  final bool isPaused;

  bool get _isLastPage => currentIndex == pageCount - 1;

  @override
  Widget build(BuildContext context) {
    final listen = PillButton(
      label: 'Listen Again',
      leadingIcon: Icons.volume_up_rounded,
      variant: PillButtonVariant.soft,
      onPressed: onListenAgain,
    );
    final next = PillButton(
      label: _isLastPage ? 'Finish' : 'Next',
      trailingIcon:
          _isLastPage ? Icons.check_rounded : Icons.arrow_forward_rounded,
      onPressed: onNext,
    );
    final dots = PageDots(count: pageCount, index: currentIndex);
    final toggle = onTogglePlayback == null
        ? null
        : RoundIconButton(
            icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            tooltip: isPlaying
                ? 'Pause scene'
                : isPaused
                    ? 'Resume scene'
                    : 'Play scene',
            onPressed: onTogglePlayback,
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppDimens.compactControls) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [dots, if (toggle != null) toggle]),
              const SizedBox(height: AppDimens.gapM),
              Row(
                children: [
                  Expanded(child: listen),
                  const SizedBox(width: AppDimens.gapM),
                  Expanded(child: next),
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            listen,
            if (toggle != null) toggle,
            Expanded(child: Center(child: dots)),
            next,
          ],
        );
      },
    );
  }
}
