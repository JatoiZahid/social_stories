import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/widgets.dart';

/// "Listen Again" · page dots · "Next"/"Finish".
/// One row on wide screens, dots above two equal buttons on narrow ones.
class StoryControls extends StatelessWidget {
  const StoryControls({
    super.key,
    required this.pageCount,
    required this.currentIndex,
    required this.onListenAgain,
    required this.onNext,
  });

  final int pageCount;
  final int currentIndex;
  final VoidCallback onListenAgain;
  final VoidCallback onNext;

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
      trailingIcon: _isLastPage ? Icons.check_rounded : Icons.arrow_forward_rounded,
      onPressed: onNext,
    );
    final dots = PageDots(count: pageCount, index: currentIndex);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppDimens.compactControls) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              dots,
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
            Expanded(child: Center(child: dots)),
            next,
          ],
        );
      },
    );
  }
}
