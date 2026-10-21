import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets/format.dart';
import 'submission_screen.dart';

/// The review queue, filtered by status. Pending changes are listed
/// oldest first, so they are reviewed in the order they arrived.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.api, required this.onChanged});

  final AdminApi api;

  /// Called after an approval or rejection (to update the badge).
  final VoidCallback onChanged;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  String _status = 'pending';
  late Future<List<Submission>> _loading = widget.api.submissions(_status);

  Future<void> _reload() async {
    final next = widget.api.submissions(_status);
    setState(() {
      _loading = next;
    });
    await next.catchError((_) => <Submission>[]);
  }

  Future<void> _open(Submission submission) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SubmissionScreen(api: widget.api, submissionId: submission.id)),
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'pending', label: Text('Waiting'), icon: Icon(Icons.hourglass_top_rounded)),
                ButtonSegment(value: 'approved', label: Text('Approved')),
                ButtonSegment(value: 'rejected', label: Text('Rejected')),
                ButtonSegment(value: 'all', label: Text('All')),
              ],
              selected: {_status},
              onSelectionChanged: (s) {
                _status = s.first;
                _reload();
              },
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: FutureBuilder<List<Submission>>(
              future: _loading,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _Message(icon: Icons.cloud_off_rounded, text: '${snapshot.error}', onRetry: _reload);
                }
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return _Message(
                    icon: Icons.inbox_rounded,
                    text: _status == 'pending' ? 'Nothing waiting for review.' : 'Nothing here yet.',
                    onRetry: _reload,
                  );
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _SubmissionTile(submission: items[i], onTap: () => _open(items[i])),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  const _SubmissionTile({required this.submission, required this.onTap});

  final Submission submission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = submission;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(child: Icon(typeIcon(s.type))),
        title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.type.label} · ${s.submitter}', maxLines: 1, overflow: TextOverflow.ellipsis),
            Text([if (s.createdAt != null) 'Sent ${formatDateTime(s.createdAt!)}', if (!s.isPending) statusLabel(s.status)]
                .join(' · ')),
            if (s.outdated)
              Text('The story changed since this was sent', style: TextStyle(color: theme.colorScheme.error)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, required this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // A ListView so pull-to-refresh works on the empty state too.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Center(child: TextButton(onPressed: onRetry, child: const Text('Refresh'))),
      ],
    );
  }
}
