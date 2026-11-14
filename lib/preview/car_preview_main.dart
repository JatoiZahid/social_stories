import 'package:flutter/material.dart';
import '../core/narration/narrator.dart';
import '../core/settings/app_settings.dart';
import '../core/theme/app_theme.dart';
import 'car/car_preview_screen.dart';

/// Deliberately separate entry point. Production has no route to this preview.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    title: 'Fix My Broken Car • Preview',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    home: CarPreviewScreen(narrator: TtsNarrator(), settings: AppSettings()),
  ));
}
