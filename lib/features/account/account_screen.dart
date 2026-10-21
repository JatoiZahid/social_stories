import 'package:flutter/material.dart';

import '../../core/account/account_service.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/account_api.dart';
import '../../shared/widgets/widgets.dart';

/// Grown-ups only (opened through the parent gate): sign in, subscribe,
/// turn on story editing and follow changes sent for review.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/account'),
        builder: (_) => const AccountScreen(),
      );

  @override
  Widget build(BuildContext context) {
    final account = AppScope.of(context).account;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListenableBuilder(
              listenable: account,
              builder: (context, _) => ListView(
                padding: const EdgeInsets.all(AppDimens.screenPadding),
                children: [
                  ScreenHeader(
                    title: 'Account',
                    subtitle: const InfoPill(label: 'Grown-ups'),
                    leading: RoundIconButton(
                      icon: Icons.chevron_left_rounded,
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(height: AppDimens.gapL),
                  if (!account.available)
                    const _Notice(
                      icon: Icons.cloud_off_rounded,
                      text: 'Accounts need the story server, and this copy of the app is not connected to one.',
                    )
                  else if (!account.signedIn)
                    const _SignInCard()
                  else ...[
                    _ProfileCard(account: account),
                    const SizedBox(height: AppDimens.gapL),
                    _SubscriptionCard(account: account),
                    const SizedBox(height: AppDimens.gapL),
                    _EditingCard(account: account),
                    const SizedBox(height: AppDimens.gapL),
                    _SubmissionsCard(account: account),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sign in / create account ────────────────────────────────────────────

class _SignInCard extends StatefulWidget {
  const _SignInCard();

  @override
  State<_SignInCard> createState() => _SignInCardState();
}

class _SignInCardState extends State<_SignInCard> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _creating = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final account = AppScope.read(context).account;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_creating) {
        await account.register(email: _email.text, password: _password.text, name: _name.text);
      } else {
        await account.signIn(email: _email.text, password: _password.text);
      }
    } on ApiError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_creating ? 'Create an account' : 'Sign in',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppDimens.gapS),
            Text(
              'With a subscription you can add new stories, improve existing ones and write quiz questions. '
              'Our team checks every change before children see it.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: AppDimens.gapL),
            if (_creating) ...[
              _Field(controller: _name, label: 'Your name (optional)', autofill: AutofillHints.name),
              const SizedBox(height: AppDimens.gapM),
            ],
            _Field(
              controller: _email,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              autofill: AutofillHints.email,
            ),
            const SizedBox(height: AppDimens.gapM),
            _Field(
              controller: _password,
              label: _creating ? 'Password (at least 8 characters)' : 'Password',
              obscure: true,
              autofill: _creating ? AutofillHints.newPassword : AutofillHints.password,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.gapM),
              Text(_error!, style: textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: AppDimens.gapL),
            Align(
              alignment: Alignment.centerLeft,
              child: PillButton(
                label: _busy ? 'Please wait…' : (_creating ? 'Create Account' : 'Sign In'),
                leadingIcon: _creating ? Icons.person_add_alt_1_rounded : Icons.login_rounded,
                onPressed: _busy ? null : _submit,
              ),
            ),
            const SizedBox(height: AppDimens.gapS),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy ? null : () => setState(() {
                  _creating = !_creating;
                  _error = null;
                }),
                child: Text(_creating ? 'I already have an account' : 'New here? Create an account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.obscure = false,
    this.keyboardType,
    this.autofill,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? autofill;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autocorrect: false,
      enableSuggestions: !obscure,
      autofillHints: autofill == null ? null : [autofill!],
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.tint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimens.radiusM)),
      ),
    );
  }
}

// ── Signed in ───────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.account});

  final AccountService account;

  @override
  Widget build(BuildContext context) {
    final a = account.account!;
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.tint,
            child: Icon(Icons.person_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: AppDimens.gapM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.displayName, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                if (a.name.trim().isNotEmpty)
                  Text(a.email, style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              AppScope.read(context).settings.editMode = false;
              account.signOut();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatefulWidget {
  const _SubscriptionCard({required this.account});

  final AccountService account;

  @override
  State<_SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<_SubscriptionCard> {
  late final Future<String?> _price = widget.account.billing.price();
  bool _checking = false;

  Future<void> _checkAgain() async {
    setState(() => _checking = true);
    try {
      await widget.account.refresh();
    } on ApiError catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account.account!;
    final textTheme = Theme.of(context).textTheme;
    final until = a.subscribedUntil;
    final status = !a.subscribed
        ? 'No subscription yet.'
        : until == null
            ? 'Your subscription is active.'
            : 'Your subscription is active until ${_date(until)}.';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(a.subscribed ? Icons.verified_rounded : Icons.workspace_premium_outlined,
                  color: a.subscribed ? AppColors.primary : AppColors.inkSoft),
              const SizedBox(width: AppDimens.gapS),
              Text('Subscription', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: AppDimens.gapS),
          Text(status, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
          if (a.subscribed && a.subscriptionSource == 'google_play')
            Text('Paid through Google Play. Manage or cancel it in the Play Store.',
                style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft)),
          if (!a.subscribed) ...[
            const SizedBox(height: AppDimens.gapS),
            Text(
              'A subscription lets you add and edit stories and their quiz questions.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: AppDimens.gapL),
            FutureBuilder<String?>(
              future: _price,
              builder: (context, snapshot) {
                final price = snapshot.data;
                if (price == null) {
                  return Text(
                    snapshot.connectionState == ConnectionState.done
                        ? 'Ask the app\'s admin to turn on your subscription, then tap "Check again".'
                        : 'Loading…',
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
                  );
                }
                return Wrap(
                  spacing: AppDimens.gapM,
                  runSpacing: AppDimens.gapS,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    PillButton(
                      label: 'Subscribe · $price',
                      leadingIcon: Icons.shopping_bag_rounded,
                      onPressed: widget.account.buySubscription,
                    ),
                    TextButton(onPressed: widget.account.restorePurchases, child: const Text('Restore purchase')),
                  ],
                );
              },
            ),
            ValueListenableBuilder<String?>(
              valueListenable: widget.account.billing.message,
              builder: (context, message, _) => message == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: AppDimens.gapS),
                      child: Text(message, style: textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft)),
                    ),
            ),
          ],
          const SizedBox(height: AppDimens.gapS),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _checking ? null : _checkAgain,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Check again'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditingCard extends StatelessWidget {
  const _EditingCard({required this.account});

  final AccountService account;

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    final subscribed = account.subscribed;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.gapL, vertical: AppDimens.gapS),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.edit_note_rounded, color: AppColors.primary),
        title: const Text('Edit stories'),
        subtitle: Text(subscribed
            ? 'Add stories, change pages and write quiz questions. Changes are sent for review.'
            : 'Needs an active subscription.'),
        value: subscribed && settings.editMode,
        onChanged: !subscribed
            ? null
            : (value) {
                settings.editMode = value;
                // Land on the library, where every story can now be edited.
                if (value) Navigator.of(context).popUntil((route) => route.isFirst);
              },
      ),
    );
  }
}

class _SubmissionsCard extends StatefulWidget {
  const _SubmissionsCard({required this.account});

  final AccountService account;

  @override
  State<_SubmissionsCard> createState() => _SubmissionsCardState();
}

class _SubmissionsCardState extends State<_SubmissionsCard> {
  late Future<List<Submission>> _loading = widget.account.submissions();

  void _reload() => setState(() {
        _loading = widget.account.submissions();
      });

  Future<void> _withdraw(Submission submission) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'Take back this change?',
      message: '"${submission.title}" will not be reviewed.',
      confirmLabel: 'Take Back',
      icon: Icons.undo_rounded,
    );
    if (!ok) return;
    try {
      await widget.account.withdraw(submission.id);
      _reload();
    } on ApiError catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Sent for review', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              IconButton(tooltip: 'Refresh', onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          FutureBuilder<List<Submission>>(
            future: _loading,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Could not load your changes. ${snapshot.error}',
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft));
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(AppDimens.gapL),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final items = snapshot.data!;
              if (items.isEmpty) {
                return Text('Nothing yet. Changes you send appear here with the review result.',
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft));
              }
              return Column(
                children: [
                  for (final s in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _StatusIcon(status: s.status),
                      title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text([
                        '${s.type.label} · ${_statusLabel(s.status)}',
                        if (s.createdAt != null) 'Sent ${_date(s.createdAt!)}',
                        if (s.reviewNote != null) 'Reviewer: ${s.reviewNote}',
                      ].join('\n')),
                      isThreeLine: s.reviewNote != null || s.createdAt != null,
                      trailing: s.isPending
                          ? TextButton(onPressed: () => _withdraw(s), child: const Text('Take back'))
                          : null,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      'approved' => (Icons.check_circle_rounded, Colors.green.shade600),
      'rejected' => (Icons.cancel_rounded, Theme.of(context).colorScheme.error),
      'withdrawn' => (Icons.undo_rounded, AppColors.inkSoft),
      _ => (Icons.hourglass_top_rounded, AppColors.primary),
    };
    return Icon(icon, color: color, semanticLabel: _statusLabel(status));
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Row(
          children: [
            Icon(icon, color: AppColors.inkSoft),
            const SizedBox(width: AppDimens.gapM),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

String _statusLabel(String status) => switch (status) {
      'approved' => 'Approved and published',
      'rejected' => 'Not approved',
      'withdrawn' => 'Taken back',
      _ => 'Waiting for review',
    };

String _date(DateTime d) => '${d.day} ${const [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ][d.month - 1]} ${d.year}';
