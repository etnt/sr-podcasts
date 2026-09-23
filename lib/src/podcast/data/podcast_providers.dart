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
