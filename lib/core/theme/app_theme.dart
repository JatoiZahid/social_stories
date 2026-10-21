import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_dimens.dart';

abstract final class AppTheme {
  /// [useGoogleFonts] is off in tests so no font download is attempted.
  static ThemeData light({bool useGoogleFonts = true}) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    final textTheme = (useGoogleFonts ? GoogleFonts.nunitoTextTheme(base.textTheme) : base.textTheme)
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

    return base.copyWith(
      textTheme: textTheme,
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXL)),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary,
        thumbColor: AppColors.primary,
        inactiveTrackColor: AppColors.border,
      ),
    );
  }
}
