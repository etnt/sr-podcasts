import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../audio/podcast_playback.dart';
import '../data/podcast_catalog.dart';
import '../data/podcast_providers.dart';
import '../domain/podcast_episode.dart';
import '../domain/podcast_program.dart';
import 'widgets/episode_player_controls.dart';

class PodcastScreen extends ConsumerWidget {
  const PodcastScreen({super.key, this.program});

  final PodcastProgram? program;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProgram = program ?? podcastCatalog.first;
    final episodes = ref.watch(episodesProvider(selectedProgram));

    return Scaffold(
      appBar: AppBar(
        title: const Text('SR Podcasts'),
        actions: [
          IconButton(
            tooltip: 'Open Sveriges Radio page',
            onPressed: () => _openProgramPage(context, selectedProgram),
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: Column(
        children: [
          _ProgramHeader(program: selectedProgram),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(episodesProvider(selectedProgram)),
              child: episodes.when(
                loading: () => const _ScrollableMessage(
                  child: CircularProgressIndicator(),
                ),
                error: (error, _) => _ScrollableMessage(
                  child: _LoadError(
                    error: error,
                    onRetry: () =>
                        ref.invalidate(episodesProvider(selectedProgram)),
                    onOpenPage: () =>
                        _openProgramPage(context, selectedProgram),
                  ),
                ),
                data: (items) => items.isEmpty
                    ? const _ScrollableMessage(
                        child: Text('No episodes are currently available.'),
                      )
                    : _EpisodeList(episodes: items),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const EpisodePlayerControls(),
    );
  }

  Future<void> _openProgramPage(
    BuildContext context,
    PodcastProgram selectedProgram,
  ) async {
    final opened = await launchUrl(
      selectedProgram.pageUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the Sveriges Radio page.'),
        ),
      );
    }
  }
}

class _ProgramHeader extends StatelessWidget {
  const _ProgramHeader({required this.program});

  final PodcastProgram program;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.square(
              dimension: 76,
              child: program.imageUrl == null
                  ? const _ImagePlaceholder()
                  : Image.network(
                      program.imageUrl.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const _ImagePlaceholder(),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  program.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Senaste avsnitt',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Icon(
      Icons.podcasts,
      size: 34,
      color: Theme.of(context).colorScheme.onSecondaryContainer,
    ),
  );
}

class _ScrollableMessage extends StatelessWidget {
  const _ScrollableMessage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [SizedBox(height: 300, child: Center(child: child))],
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({
    required this.error,
    required this.onRetry,
    required this.onOpenPage,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onOpenPage;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off, size: 42),
        const SizedBox(height: 12),
        Text(
          'Could not load episodes',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          error.toString(),
          textAlign: TextAlign.center,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            OutlinedButton.icon(
              onPressed: onOpenPage,
              icon: const Icon(Icons.open_in_new),
              label: const Text('SR page'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _EpisodeList extends StatelessWidget {
  const _EpisodeList({required this.episodes});

  final List<PodcastEpisode> episodes;

  @override
  Widget build(BuildContext context) => ListView.separated(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
    itemCount: episodes.length,
    separatorBuilder: (context, index) => const SizedBox(height: 4),
    itemBuilder: (context, index) => _EpisodeTile(episode: episodes[index]),
  );
}

class _EpisodeTile extends ConsumerWidget {
  const _EpisodeTile({required this.episode});

  final PodcastEpisode episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final isCurrentEpisode = playback.episode?.id == episode.id;
    return Card(
      child: ListTile(
        key: ValueKey('episode-${episode.id}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(
            isCurrentEpisode ? Icons.volume_up : Icons.podcasts,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(
          episode.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (episode.publishedAt case final publishedAt?)
                Text(_formatDate(publishedAt)),
              if (episode.description case final description?)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (episode.duration case final duration?)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(_formatDuration(duration)),
                ),
            ],
          ),
        ),
        trailing: IconButton(
          tooltip: episode.isPlayable
              ? 'Play ${episode.title}'
              : 'Open episode on Sveriges Radio',
          onPressed: episode.isPlayable
              ? () => ref.read(playbackProvider.notifier).playEpisode(episode)
              : () => _openEpisode(context, episode),
          icon: Icon(episode.isPlayable ? Icons.play_arrow : Icons.open_in_new),
        ),
        onTap: episode.isPlayable
            ? () => ref.read(playbackProvider.notifier).playEpisode(episode)
            : () => _openEpisode(context, episode),
      ),
    );
  }

  Future<void> _openEpisode(
    BuildContext context,
    PodcastEpisode episode,
  ) async {
    final pageUrl = episode.pageUrl ?? podcastCatalog.first.pageUrl;
    final opened = await launchUrl(
      pageUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this episode.')),
      );
    }
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return minutes >= 60
        ? '${duration.inHours}:${minutes.remainder(60).toString().padLeft(2, '0')}:$seconds'
        : '$minutes:$seconds';
  }
}
