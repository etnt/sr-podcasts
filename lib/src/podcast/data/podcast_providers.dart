import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../domain/podcast_episode.dart';
import '../domain/podcast_program.dart';
import 'sr_api_client.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final srApiClientProvider = Provider<SrApiClient>((ref) {
  return SrApiClient(httpClient: ref.watch(httpClientProvider));
});

final episodesProvider =
    FutureProvider.family<List<PodcastEpisode>, PodcastProgram>(
      (ref, program) => ref.watch(srApiClientProvider).fetchEpisodes(program),
      retry: (retryCount, error) => null,
    );

/// In-memory cache of the full SR program catalog used by search. Fetched
/// once per session (~842 KB) and reused for every keystroke.
final allProgramsProvider = FutureProvider<List<PodcastProgram>>(
  (ref) => ref.watch(srApiClientProvider).fetchAllPrograms(),
  retry: (retryCount, error) => null,
);
