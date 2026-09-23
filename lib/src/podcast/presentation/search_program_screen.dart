import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/podcast_providers.dart';
import '../data/subscriptions.dart';
import '../domain/podcast_program.dart';
import 'podcast_screen.dart';
import 'widgets/program_artwork.dart';

/// Search screen: filters the in-memory SR program catalog (fetched once per
/// session) by name/description and lets the user subscribe to podcasts.
class SearchProgramScreen extends ConsumerStatefulWidget {
  const SearchProgramScreen({super.key});

  @override
  ConsumerState<SearchProgramScreen> createState() =>
      _SearchProgramScreenState();
}

class _SearchProgramScreenState extends ConsumerState<SearchProgramScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final corpus = ref.watch(allProgramsProvider);
    final subscribedIds = {
      for (final program
          in ref.watch(subscriptionsProvider).value ?? const <PodcastProgram>[])
        program.id,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Find shows')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search Sveriges Radio podcasts',
                border: const OutlineInputBorder(),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _query = ''),
                      ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: corpus.when(
              loading: () => const _StatusMessage(
                icon: CircularProgressIndicator(),
                message: 'Loading the SR catalog…',
              ),
              error: (error, _) => _SearchError(
                error: error,
                onRetry: () => ref.invalidate(allProgramsProvider),
              ),
              data: (programs) {
                final results = _filter(programs, _query);
                if (_query.trim().isEmpty) {
                  return const _StatusMessage(
                    icon: Icon(Icons.manage_search, size: 42),
                    message:
                        'Search all Sveriges Radio podcasts by name or description.',
                  );
                }
                if (results.isEmpty) {
                  return _StatusMessage(
                    icon: const Icon(Icons.search_off, size: 42),
                    message: 'No shows match “${_query.trim()}”.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: results.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 4),
                  itemBuilder: (context, index) => _SearchResultTile(
                    program: results[index],
                    isSubscribed: subscribedIds.contains(results[index].id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Case-insensitive substring search over podcast programs only.
  static List<PodcastProgram> _filter(
    List<PodcastProgram> programs,
    String query,
  ) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    return programs
        .where((program) => program.hasPod)
        .where(
          (program) =>
              program.name.toLowerCase().contains(needle) ||
              (program.description?.toLowerCase().contains(needle) ?? false),
        )
        .toList();
  }
}

class _SearchResultTile extends ConsumerWidget {
  const _SearchResultTile({required this.program, required this.isSubscribed});

  final PodcastProgram program;
  final bool isSubscribed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        key: ValueKey('search-${program.id}'),
        leading: ProgramArtwork(program: program),
        title: Text(program.name),
        subtitle: program.description == null
            ? null
            : Text(
                program.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: IconButton(
          tooltip: isSubscribed
              ? 'Unsubscribe from ${program.name}'
              : 'Subscribe to ${program.name}',
          icon: Icon(isSubscribed ? Icons.bookmark : Icons.bookmark_border),
          onPressed: () => unawaited(
            ref.read(subscriptionsProvider.notifier).toggle(program),
          ),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PodcastScreen(program: program),
          ),
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.icon, required this.message});

  final Widget icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _SearchError extends StatelessWidget {
  const _SearchError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 42),
          const SizedBox(height: 12),
          Text(
            'Could not load the SR catalog',
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
