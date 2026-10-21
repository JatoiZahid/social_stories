import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/account/account_service.dart';
import 'core/account/billing.dart';
import 'core/app_config.dart';
import 'core/narration/narrator.dart';
import 'core/settings/app_settings.dart';
import 'data/account_api.dart';
import 'data/story_repository.dart';
import 'data/story_storage.dart';
import 'data/story_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final server = AppConfig.storyServer;
  final onAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final account = AccountService(
    api: server == null ? null : AccountApi(server),
    tokenStorage: const SharedPrefsStoryStorage(SharedPrefsStoryStorage.sessionKey),
    billing: onAndroid && server != null ? PlayBilling() : NoBilling(),
  )..restore();
  runApp(
    StorybookApp(
      settings: AppSettings(),
      narrator: TtsNarrator(),
      store: StoryStore(
        repository: const StoryRepository(),
        storage: const SharedPrefsStoryStorage(),
        remote: server == null ? null : RemoteStoryRepository(server),
        serverCache: const SharedPrefsStoryStorage(SharedPrefsStoryStorage.serverCacheKey),
      ),
      account: account,
    ),
  );
}
