import 'package:flutter/foundation.dart';

import '../../data/account_api.dart';
import '../../data/models/story.dart';
import '../../data/story_storage.dart';
import '../../data/story_store.dart';
import 'billing.dart';

/// The signed-in account, its subscription, and sending drafts for review.
class AccountService extends ChangeNotifier {
  AccountService({required this.api, required this.tokenStorage, Billing? billing})
      : billing = billing ?? NoBilling() {
    this.billing.onPurchase = _onPurchase;
  }

  /// Null when the app has no story server (accounts need one).
  final AccountApi? api;

  /// Keeps the session token so the user stays signed in.
  final StoryStorage tokenStorage;
  final Billing billing;

  String? _token;
  Account? _account;
  Future<void>? _restoring;
  bool _disposed = false;

  bool get available => api != null;
  Account? get account => _account;
  bool get signedIn => _account != null;
  bool get subscribed => _account?.subscribed ?? false;

  /// Signs back in with the saved token, if there is one.
  Future<void> restore() => _restoring ??= _restore();

  Future<void> _restore() async {
    if (api == null) return;
    try {
      _token = await tokenStorage.read();
      if (_token != null) await refresh();
    } catch (error) {
      debugPrint('Could not restore the account: $error');
    }
  }

  Future<void> register({required String email, required String password, String name = ''}) async {
    final result = await _api.register(email.trim(), password, name.trim());
    await _signedIn(result.token, result.account);
  }

  Future<void> signIn({required String email, required String password}) async {
    final result = await _api.signIn(email.trim(), password);
    await _signedIn(result.token, result.account);
  }

  Future<void> signOut() async {
    final token = _token;
    _token = null;
    _account = null;
    await tokenStorage.clear();
    _notify();
    if (token != null) {
      try {
        await _api.signOut(token);
      } catch (_) {
        // Signed out on this device either way.
      }
    }
  }

  /// Reloads the account (e.g. to see a new subscription). A rejected token signs out.
  Future<void> refresh() async {
    final token = _token;
    if (token == null) return;
    try {
      _account = await _api.me(token);
      _notify();
    } on ApiError catch (error) {
      if (error.isSignedOut) {
        await signOut();
      } else {
        rethrow;
      }
    }
  }

  Future<List<Submission>> submissions() => _api.submissions(_requireToken());

  Future<void> withdraw(String id) async {
    await _api.withdraw(_requireToken(), id);
    await refresh();
  }

  /// Sends the draft of [storyId] for review: a new story, story changes
  /// and/or new quiz questions. The draft is removed once it is sent.
  /// Returns what was sent.
  Future<List<SubmissionType>> submitDraft(StoryStore store, String storyId) async {
    final token = _requireToken();
    final draft = store.draft(storyId);
    if (draft == null) throw const ApiError('This story no longer exists.');
    _checkComplete(draft);

    final published = store.published(storyId);
    final sends = <SubmissionType>[
      if (published == null) SubmissionType.newStory,
      if (published != null && !draft.samePagesAs(published)) SubmissionType.editStory,
      if (published != null && !draft.sameQuestionsAs(published)) SubmissionType.editQuestions,
    ];
    if (sends.isEmpty) throw const ApiError('Nothing has changed yet. Edit the story or its questions first.');

    for (final type in sends) {
      await _api.submit(token, type, draft);
    }
    store.discardDraft(storyId);
    await refresh();
    return sends;
  }

  static void _checkComplete(Story story) {
    if (story.title.trim().isEmpty) throw const ApiError('Give the story a title first.');
    for (var i = 0; i < story.pages.length; i++) {
      if (story.pages[i].narration.isEmpty) throw ApiError('Page ${i + 1} has no words yet.');
    }
    for (var i = 0; i < story.questions.length; i++) {
      if (!story.questions[i].isComplete) {
        throw ApiError('Question ${i + 1} is not finished: it needs text, at least 2 answers and a right answer.');
      }
    }
  }

  // ── Google Play ────────────────────────────────────────────────────────

  Future<void> buySubscription() async {
    final account = _account;
    if (account == null) throw const ApiError('Please sign in first.');
    await billing.buy(account.id);
  }

  Future<void> restorePurchases() async {
    final account = _account;
    if (account != null) await billing.restore(account.id);
  }

  Future<bool> _onPurchase(String productId, String purchaseToken) async {
    final token = _token;
    if (token == null) return false;
    try {
      _account = await _api.attachGooglePlay(token, productId: productId, purchaseToken: purchaseToken);
      _notify();
      return true;
    } catch (error) {
      debugPrint('The server did not accept the purchase: $error');
      return false;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  AccountApi get _api {
    final api = this.api;
    if (api == null) throw const ApiError('Accounts need a story server, and none is set up in this app.');
    return api;
  }

  String _requireToken() {
    final token = _token;
    if (token == null) throw const ApiError('Please sign in first.');
    return token;
  }

  Future<void> _signedIn(String token, Account account) async {
    _token = token;
    _account = account;
    await tokenStorage.write(token);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    billing.dispose();
    super.dispose();
  }
}
