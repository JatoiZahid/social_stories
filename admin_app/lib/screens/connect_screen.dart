import 'package:flutter/material.dart';

import '../api.dart';
import '../session.dart';

/// First screen: the story server's address and the admin token
/// (both are shown in the server window when it starts).
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key, required this.session});

  final Session session;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  late final _server = TextEditingController(text: widget.session.server);
  final _token = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _server.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.connect(_server.text, _token.text);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Icon(Icons.admin_panel_settings_rounded, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text('Stories Admin', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Connect to the story server. Its address and the admin token are shown in the server window.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _server,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Server address',
                    hintText: 'http://192.168.1.20:8080',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _token,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  onSubmitted: (_) => _connect(),
                  decoration: const InputDecoration(labelText: 'Admin token', border: OutlineInputBorder()),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy ? null : _connect,
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.login_rounded),
                  label: const Text('Connect'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
