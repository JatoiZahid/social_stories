import 'package:flutter/material.dart';

import 'core/account/account_service.dart';
import 'core/app_scope.dart';
import 'core/narration/narrator.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'data/story_store.dart';
import 'features/library/library_screen.dart';

/// Root widget. Dependencies are injected so tests can swap them out.
class StorybookApp extends StatelessWidget {
  const StorybookApp({
    super.key,
    required this.settings,
    required this.narrator,
    required this.store,
    required this.account,
    this.theme,
  });

  final AppSettings settings;
  final Narrator narrator;
  final StoryStore store;
  final AccountService account;
  final ThemeData? theme;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      settings: settings,
      narrator: narrator,
      store: store,
      account: account,
      child: MaterialApp(
        title: 'Social Stories',
        debugShowCheckedModeBanner: false,
        theme: theme ?? AppTheme.light(),
        home: const LibraryScreen(),
      ),
    );
  }
}
