import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// Which server the admin app talks to, and with which admin token.
/// Both are remembered on the device.
class Session extends ChangeNotifier {
  static const _serverKey = 'server_url';
  static const _tokenKey = 'admin_token';

  /// Prefilled server address: `--dart-define=STORY_SERVER_URL=...`
  /// (the build script reads it from story_server.txt), else the emulator's view of this PC.
  static const String defaultServer =
      String.fromEnvironment('STORY_SERVER_URL', defaultValue: 'http://10.0.2.2:8080');

  AdminApi? _api;
  String _server = defaultServer;
  bool _loaded = false;

  AdminApi? get api => _api;
  String get server => _server;
  bool get loaded => _loaded;

  /// Reconnects with the saved address and token, if any.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _server = prefs.getString(_serverKey) ?? defaultServer;
    final token = prefs.getString(_tokenKey);
    final url = Uri.tryParse(_server);
    if (token != null && url != null) _api = AdminApi(url, token);
    _loaded = true;
    notifyListeners();
  }

  /// Checks the address and token with the server, then remembers them.
  Future<void> connect(String server, String token) async {
    var address = server.trim();
    if (!address.startsWith('http://') && !address.startsWith('https://')) address = 'http://$address';
    if (address.endsWith('/')) address = address.substring(0, address.length - 1);
    final url = Uri.tryParse(address);
    if (url == null || url.host.isEmpty) throw const ApiError('That does not look like a server address.');
    final api = AdminApi(url, token.trim());
    try {
      await api.check();
    } on ApiError catch (e) {
      if (e.status == 401) throw const ApiError('The admin token is not right. It is shown in the server window.');
      rethrow;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverKey, address);
    await prefs.setString(_tokenKey, token.trim());
    _server = address;
    _api = api;
    notifyListeners();
  }

  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _api = null;
    notifyListeners();
  }
}
