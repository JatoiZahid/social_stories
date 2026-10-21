import 'package:flutter/material.dart';

import '../api.dart';
import '../session.dart';
import 'review_screen.dart';
import 'users_screen.dart';

/// Two tabs: the review queue and the subscribers.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api, required this.session});

  final AdminApi api;
  final Session session;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  Summary? _summary;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await widget.api.summary();
      if (mounted) setState(() => _summary = summary);
    } on ApiError catch (e) {
      if (e.status == 401) await widget.session.disconnect();
    }
  }

  Future<void> _disconnect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect?'),
        content: Text('You will need the admin token to connect to ${widget.session.server} again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Disconnect')),
        ],
      ),
    );
    if (ok == true) await widget.session.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _summary?.pending ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? 'Review' : 'Subscribers'),
        actions: [
          IconButton(tooltip: 'Disconnect', onPressed: _disconnect, icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          ReviewScreen(api: widget.api, onChanged: _loadSummary),
          UsersScreen(api: widget.api, onChanged: _loadSummary),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: const Icon(Icons.fact_check_outlined),
            ),
            selectedIcon: const Icon(Icons.fact_check_rounded),
            label: 'Review',
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline_rounded),
            selectedIcon: const Icon(Icons.people_rounded),
            label: _summary == null ? 'Subscribers' : 'Subscribers (${_summary!.subscribers})',
          ),
        ],
      ),
    );
  }
}
