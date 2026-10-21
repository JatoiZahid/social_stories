import 'package:flutter/widgets.dart';

import '../data/story_store.dart';
import 'account/account_service.dart';
import 'narration/narrator.dart';
import 'settings/app_settings.dart';

/// Makes app-wide services available to every screen and component.
/// Widgets that call [of] rebuild when [AppSettings] changes.
class AppScope extends InheritedNotifier<AppSettings> {
  const AppScope({
    super.key,
    required AppSettings settings,
    required this.narrator,
    required this.store,
    required this.account,
    required super.child,
  }) : super(notifier: settings);

  final Narrator narrator;

  /// Published stories and this device's drafts. Listen to it for changes.
  final StoryStore store;

  /// Sign-in, subscription and sending drafts for review. Listen to it for changes.
  final AccountService account;

  AppSettings get settings => notifier!;

  /// Use in `build` – subscribes to settings changes.
  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found above this widget.');
    return scope!;
  }

  /// Use in callbacks – does not subscribe.
  static AppScope read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found above this widget.');
    return scope!;
  }
}
