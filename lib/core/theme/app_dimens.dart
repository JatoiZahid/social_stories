/// Spacing, radii and breakpoints shared by every component.
abstract final class AppDimens {
  static const double radiusXL = 24;
  static const double radiusL = 18;
  static const double radiusM = 12;
  static const double radiusS = 9;

  static const double gapXS = 4;
  static const double gapS = 8;
  static const double gapM = 12;
  static const double gapL = 16;
  static const double gapXL = 24;

  static const double screenPadding = 16;
  static const double minTapTarget = 48;

  /// Story page switches from stacked to side-by-side above this width.
  static const double wideStoryLayout = 560;

  /// Controls switch from one row to two rows below this width.
  static const double compactControls = 420;

  static const double maxStoryWidth = 1000;
  static const double maxLibraryWidth = 1200;
}
