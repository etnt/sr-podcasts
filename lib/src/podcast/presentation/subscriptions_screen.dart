import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_version.dart';
import '../data/subscriptions.dart';
import '../data/update_service.dart';
import '../domain/podcast_program.dart';
import 'podcast_screen.dart';
import 'search_program_screen.dart';
import 'update_prompt.dart';
import 'widgets/program_artwork.dart';

/// Home screen: the list of locally subscribed Sveriges Radio shows.
class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() =>
      _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  /// Ensures the startup update check runs at most once per state instance.
  bool _updateCheckStarted = false;

  @override
  void initState() {
    super.initState();
    // Fire-and-forget update check, deferred to after the first frame so the
    // dialog never collides with the initial build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  /// Runs the throttled GitHub Releases check and, on a newer release, shows
  /// the dialog. "Update now" opens the release page in the browser; nothing
  /// opens without the user's explicit tap.
  void _checkForUpdate() {
    if (_updateCheckStarted || !mounted) return;
    _updateCheckStarted = true;
    maybeShowUpdateDialog(
      context,
      checker: ref.read(releaseCheckerProvider),
      onUpdate: (info) async {
        final uri = Uri.tryParse(info.releasePageUrl);
        if (uri == null) return;
        try {
          // A `false` or throw result is handled silently: the user can still
          // find the release page in the repository.
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final subscriptions = ref.watch(subscriptionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text.rich(
          TextSpan(
            text: 'SR Podcasts',
            children: [
              TextSpan(
                text: '  $appVersion',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Find new shows',
            icon: const Icon(Icons.search),
            onPressed: () => _openSearch(context),
          ),
        ],
      ),
      body: subscriptions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadError(
          error: error,
          onRetry: () => ref.invalidate(subscriptionsProvider),
        ),
        data: (shows) {
          if (shows.isEmpty) {
            return _EmptyState(onFindShows: () => _openSearch(context));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            itemCount: shows.length,
            separatorBuilder: (context, index) => const SizedBox(height: 4),
            itemBuilder: (context, index) => _ShowTile(show: shows[index]),
          );
        },
      ),
    );
  }

  void _openSearch(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SearchProgramScreen()),
    );
  }
}

class _ShowTile extends ConsumerWidget {
  const _ShowTile({required this.show});

  final PodcastProgram show;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        key: ValueKey('show-${show.id}'),
        leading: ProgramArtwork(program: show),
        title: Text(show.name),
        subtitle: show.description == null
            ? null
            : Text(
                show.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: IconButton(
          tooltip: 'Unsubscribe from ${show.name}',
          icon: const Icon(Icons.bookmark),
          onPressed: () =>
              unawaited(ref.read(subscriptionsProvider.notifier).toggle(show)),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => PodcastScreen(program: show)),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onFindShows});

  final VoidCallback onFindShows;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.subscriptions, size: 42),
          const SizedBox(height: 12),
          Text(
            'No subscribed shows',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text('Find Sveriges Radio podcasts to follow here.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onFindShows,
            icon: const Icon(Icons.search),
            label: const Text('Find shows'),
          ),
        ],
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 42),
          const SizedBox(height: 12),
          Text(
            'Could not load subscriptions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(error.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
