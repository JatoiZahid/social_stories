import 'package:flutter/material.dart';
import '../core/narration/narrator.dart';
import '../core/settings/app_settings.dart';
import '../core/theme/app_theme.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/pill_button.dart';
import '../shared/widgets/screen_header.dart';
import 'tyre/tyre_screen.dart';
import 'tyre/tyre_game.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TyrePreviewApp());
}

class TyrePreviewApp extends StatefulWidget {
  const TyrePreviewApp({super.key});
  @override
  State<TyrePreviewApp> createState() => _TyrePreviewAppState();
}

class _TyrePreviewAppState extends State<TyrePreviewApp> {
  final game = TyreGame();
  final settings = AppSettings();
  @override
  void dispose() {
    game.dispose();
    settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'Fix My Broken Car • Tyre Preview',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Builder(
          builder: (context) => Scaffold(
              body: SafeArea(
                  child: Center(
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 620),
                          child: SingleChildScrollView(
                              child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: AppCard(
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                        const ScreenHeader(
                                            title: 'Fix My Broken Car'),
                                        const SizedBox(height: 16),
                                        ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            child: Image.asset(
                                                'assets/images/story_scenes/tyre_v3_workshop.png',
                                                height: 260,
                                                fit: BoxFit.cover)),
                                        const SizedBox(height: 20),
                                        const Text(
                                            'One little wheel. A big helping hand.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 10),
                                        const Text(
                                            'A toy garage, illustrated tools, and a complete tyre repair.',
                                            textAlign: TextAlign.center),
                                        const SizedBox(height: 20),
                                        Semantics(
                                            container: true,
                                            button: true,
                                            label: 'Enter garage',
                                            child: PillButton(
                                                label: 'Enter garage',
                                                onPressed: () => Navigator.push(
                                                    context,
                                                    MaterialPageRoute<void>(
                                                        builder: (_) =>
                                                            TyreGarageScreen(
                                                                game: game,
                                                                ownsNarrator:
                                                                    true,
                                                                narrator:
                                                                    TtsNarrator(),
                                                                settings:
                                                                    settings))))),
                                      ]))))))))));
}
