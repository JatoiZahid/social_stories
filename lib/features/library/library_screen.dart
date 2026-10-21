import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/story.dart';
import '../../shared/widgets/widgets.dart';
import '../editor/story_editor_screen.dart';
import '../story/story_screen.dart';

/// Grid of every story. Children tap to read; in edit mode (subscribers) a
/// tap opens the editor and a "New story" tile appears.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  Future<void>? _loading;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loading ??= AppScope.read(context).store.load();
  }

  void _retry() => setState(() {
        _loading = AppScope.read(context).store.reload();
      });

  /// Pull down to get the latest stories from the story server.
  Future<void> _refresh() async {
    final ok = await AppScope.read(context).store.refresh();
    if (ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not reach the story server. Showing saved stories.')),
    );
  }

  void _open(Story story, {required bool editing}) {
    final navigator = Navigator.of(context);
    if (editing) {
      navigator.push(StoryEditorScreen.route(story.id));
    } else {
      navigator.push(StoryScreen.route(story));
    }
  }

  void _createStory() {
    final story = AppScope.read(context).store.createStory();
    Navigator.of(context).push(StoryEditorScreen.route(story.id));
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return ListenableBuilder(
      listenable: scope.account,
      builder: (context, _) => _build(context, scope, editing: scope.settings.editMode && scope.account.subscribed),
    );
  }

  Widget _build(BuildContext context, AppScope scope, {required bool editing}) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppDimens.maxLibraryWidth),
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.screenPadding),
              child: Column(
                children: [
                  ScreenHeader(
                    title: 'Social Stories',
                    subtitle: Text(
                      editing ? 'Tap a story to edit it' : 'Pick a story to read together',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkSoft,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    trailing: RoundIconButton(
                      icon: Icons.settings_rounded,
                      tooltip: 'Settings',
                      onPressed: () => SettingsSheet.show(context),
                    ),
                  ),
                  if (editing) ...[
                    const SizedBox(height: AppDimens.gapM),
                    _EditModeBanner(onExit: () => scope.settings.editMode = false),
                  ],
                  const SizedBox(height: AppDimens.gapL),
                  Expanded(
                    child: FutureBuilder<void>(
                      future: _loading,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) return _LoadError(onRetry: _retry);
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        return ListenableBuilder(
                          listenable: scope.store,
                          builder: (context, _) {
                            final grid = _StoryGrid(
                              stories: editing ? scope.store.editableStories : scope.store.stories,
                              editing: editing,
                              onOpen: (story) => _open(story, editing: editing),
                              onCreate: _createStory,
                            );
                            if (!scope.store.hasServer) return grid;
                            return RefreshIndicator(onRefresh: _refresh, child: grid);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditModeBanner extends StatelessWidget {
  const _EditModeBanner({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.tint,
        borderRadius: BorderRadius.circular(AppDimens.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppDimens.gapL, AppDimens.gapS, AppDimens.gapS, AppDimens.gapS),
        child: Row(
          children: [
            const Icon(Icons.lock_open_rounded, color: AppColors.primary),
            const SizedBox(width: AppDimens.gapM),
            Expanded(
              child: Text(
                'Editing is on. Your changes are saved on this phone and published after review.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            PillButton(label: 'Done', leadingIcon: Icons.check_rounded, onPressed: onExit),
          ],
        ),
      ),
    );
  }
}

class _StoryGrid extends StatelessWidget {
  const _StoryGrid({
    required this.stories,
    required this.editing,
    required this.onOpen,
    required this.onCreate,
  });

  final List<Story> stories;
  final bool editing;
  final ValueChanged<Story> onOpen;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(), // so pull-to-refresh works with few stories
      padding: const EdgeInsets.only(bottom: AppDimens.gapL),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        mainAxisSpacing: AppDimens.gapL,
        crossAxisSpacing: AppDimens.gapL,
        childAspectRatio: 0.82,
      ),
      itemCount: stories.length + (editing ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == stories.length) return AddStoryCard(onTap: onCreate);
        final story = stories[index];
        return StoryCoverCard(
          key: ValueKey(story.id),
          story: story,
          editing: editing,
          onTap: () => onOpen(story),
        );
      },
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_rounded, size: 48, color: AppColors.inkSoft),
          const SizedBox(height: AppDimens.gapM),
          const Text('We could not open the stories.'),
          const SizedBox(height: AppDimens.gapL),
          PillButton(label: 'Try Again', leadingIcon: Icons.refresh_rounded, onPressed: onRetry),
        ],
      ),
    );
  }
}
