import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/narration/narrator.dart';
import '../../data/models/story.dart';

class StoryMoralScreen extends StatefulWidget {
  const StoryMoralScreen({super.key, required this.story});
  final Story story;

  @override
  State<StoryMoralScreen> createState() => _StoryMoralScreenState();
}

class _StoryMoralScreenState extends State<StoryMoralScreen>
    with WidgetsBindingObserver {
  Narrator? _narrator;
  bool _continuing = false;

  Future<void> _continue() async {
    if (_continuing) return;
    _continuing = true;
    await _narrator?.stop();
    _narrator = null;
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && AppScope.read(context).settings.autoRead) _listen();
    });
  }

  void _listen() {
    final scope = AppScope.read(context);
    _narrator = scope.narrator;
    _narrator!.speak('${widget.story.moral} ${widget.story.moralExplanation}',
        rate: scope.settings.speechRate);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _narrator?.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _narrator?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Moral of the story')),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
                child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lightbulb_rounded,
                    size: 56, color: Color(0xFFE8A61A)),
                const SizedBox(height: 20),
                Text(widget.story.moral,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 20),
                Text(widget.story.moralExplanation,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                        onPressed: _listen,
                        icon: const Icon(Icons.volume_up_rounded),
                        label: const Text('Listen again')),
                    FilledButton(
                        onPressed: _continue, child: const Text('Continue')),
                  ],
                ),
              ]),
            )),
          ),
        ))),
      );
}
