import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets/format.dart';

/// Everyone with an account. Tap a person to turn their subscription on
/// (with or without an end date) or off.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.api, required this.onChanged});

  final AdminApi api;
  final VoidCallback onChanged;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late Future<List<AppUser>> _loading = widget.api.users();
  String _query = '';

  Future<void> _reload() async {
    final next = widget.api.users();
    setState(() {
      _loading = next;
    });
    await next.catchError((_) => <AppUser>[]);
  }

  Future<void> _edit(AppUser user) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SubscriptionSheet(api: widget.api, user: user),
    );
    if (changed == true) {
      widget.onChanged();
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search by name or email',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: FutureBuilder<List<AppUser>>(
              future: _loading,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ListView(children: [
                    Padding(padding: const EdgeInsets.all(32), child: Text('${snapshot.error}', textAlign: TextAlign.center)),
                  ]);
                }
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final users = snapshot.data!
                    .where((u) => _query.isEmpty || u.email.contains(_query) || u.name.toLowerCase().contains(_query))
                    .toList();
                if (users.isEmpty) {
                  return ListView(children: const [
                    Padding(padding: EdgeInsets.all(32), child: Text('No accounts yet.', textAlign: TextAlign.center)),
                  ]);
                }
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: users.length,
                  itemBuilder: (context, i) {
                    final u = users[i];
                    return ListTile(
                      onTap: () => _edit(u),
                      leading: CircleAvatar(child: Text(u.displayName.characters.first.toUpperCase())),
                      title: Text(u.displayName),
                      subtitle: Text([
                        if (u.name.trim().isNotEmpty) u.email,
                        _subscriptionText(u),
                        if (u.pending > 0) '${u.pending} waiting for review',
                      ].join('\n')),
                      isThreeLine: u.name.trim().isNotEmpty || u.pending > 0,
                      trailing: Icon(
                        u.subscribed ? Icons.verified_rounded : Icons.remove_circle_outline_rounded,
                        color: u.subscribed ? Colors.green.shade600 : Theme.of(context).colorScheme.outline,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

String _subscriptionText(AppUser u) {
  if (!u.subscribed) return 'No subscription';
  final via = u.source == 'google_play' ? 'Google Play' : 'granted by admin';
  return u.until == null ? 'Subscribed ($via), no end date' : 'Subscribed ($via) until ${formatDate(u.until!)}';
}

class _SubscriptionSheet extends StatefulWidget {
  const _SubscriptionSheet({required this.api, required this.user});

  final AdminApi api;
  final AppUser user;

  @override
  State<_SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends State<_SubscriptionSheet> {
  late bool _active = widget.user.adminGranted;

  /// Last day included. The server stores the start of the next day.
  late DateTime? _lastDay = widget.user.adminUntil?.subtract(const Duration(days: 1));
  bool _busy = false;
  String? _error;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
      initialDate: _lastDay != null && _lastDay!.isAfter(now) ? _lastDay! : DateTime(now.year, now.month + 1, now.day),
      helpText: 'Last day of the subscription',
    );
    if (picked != null) setState(() => _lastDay = picked);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.setSubscription(widget.user.id, active: _active, lastDay: _active ? _lastDay : null);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final u = widget.user;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(u.displayName, style: theme.textTheme.titleLarge),
            Text(u.email),
            if (u.createdAt != null) Text('Joined ${formatDate(u.createdAt!)}', style: theme.textTheme.bodySmall),
            if (u.googleUntil != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  u.googleUntil!.isAfter(DateTime.now())
                      ? 'Google Play subscription until ${formatDate(u.googleUntil!)} (managed by Google).'
                      : 'Google Play subscription ended ${formatDate(u.googleUntil!)}.',
                ),
              ),
            const Divider(height: 32),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Subscription granted by admin'),
              subtitle: const Text('Lets them add and edit stories and quiz questions (always reviewed).'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            if (_active)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded),
                title: Text(_lastDay == null ? 'No end date' : 'Until ${formatDate(_lastDay!)} (included)'),
                trailing: Wrap(children: [
                  if (_lastDay != null)
                    IconButton(
                      tooltip: 'No end date',
                      onPressed: () => setState(() => _lastDay = null),
                      icon: const Icon(Icons.all_inclusive_rounded),
                    ),
                  IconButton(tooltip: 'Pick an end date', onPressed: _pickDate, icon: const Icon(Icons.edit_calendar_rounded)),
                ]),
              ),
            if (_error != null) Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
