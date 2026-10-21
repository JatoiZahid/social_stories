import 'package:flutter/painting.dart';

/// Palette taken from the Figma reference.
abstract final class AppColors {
  static const Color background = Color(0xFFEDF4FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color tint = Color(0xFFF2F7FE); // narration card, pills
  static const Color border = Color(0xFFD6E4F5);

  static const Color primary = Color(0xFF1F6FEB);
  static const Color primaryPressed = Color(0xFF1658C4);
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color ink = Color(0xFF22304A); // titles, lead text
  static const Color inkSoft = Color(0xFF55657F); // body text
  static const Color dotInactive = Color(0xFFCBD6E6);

  static const Color celebrate = Color(0xFFFFC233);

  static const Color shadow = Color(0x1A2B5BA8);
}
