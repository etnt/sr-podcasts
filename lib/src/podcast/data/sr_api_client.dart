import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/podcast_episode.dart';
import '../domain/podcast_program.dart';

class SrApiException implements Exception {
  const SrApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SrApiClient {
  SrApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static final Uri _apiRoot = Uri.https('api.sr.se', '/api/v2');

  final http.Client _httpClient;

  Future<List<PodcastEpisode>> fetchEpisodes(PodcastProgram program) async {
    final episodes = <PodcastEpisode>[];
    var pageUri = _apiRoot.replace(
      path: '/api/v2/episodes/index',
      queryParameters: {
        'programid': '${program.id}',
        'format': 'json',
        'size': '100',
      },
    );
    final visitedPages = <Uri>{};

    // Fetch at most 100 pages to avoid an accidental unbounded pagination loop.
    for (var page = 0; page < 100; page++) {
      if (!visitedPages.add(pageUri)) {
        throw const SrApiException(
          'Sveriges Radio returned a repeated page link.',
        );
      }
      final response = await _httpClient.get(pageUri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SrApiException(
          'Sveriges Radio returned HTTP ${response.statusCode}. Please try again.',
        );
      }

      final Map<String, dynamic> decoded;
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is! Map<String, dynamic>) {
          throw const FormatException('Expected a JSON object.');
        }
        decoded = body;
      } on FormatException catch (error) {
        throw SrApiException(
          'Could not read Sveriges Radio response: ${error.message}',
        );
      }

      final rawEpisodes = decoded['episodes'];
      if (rawEpisodes is! List) {
        throw const SrApiException(
          'Sveriges Radio response did not contain an episode list.',
        );
      }
      try {
        for (final value in rawEpisodes) {
          if (value is Map<String, dynamic>) {
            episodes.add(PodcastEpisode.fromJson(value));
          } else {
            throw const FormatException(
              'An episode entry was not a JSON object.',
            );
          }
        }
      } on FormatException catch (error) {
        throw SrApiException('Could not read an episode: ${error.message}');
      }

      final pagination = decoded['pagination'];
      final nextPage = pagination is Map<String, dynamic>
          ? pagination['nextpage']
          : null;
      if (nextPage is! String || nextPage.isEmpty) return episodes;
      final parsedNextPage = Uri.tryParse(nextPage);
      if (parsedNextPage == null ||
          parsedNextPage.scheme != 'https' ||
          parsedNextPage.host != 'api.sr.se') {
        throw const SrApiException(
          'Sveriges Radio returned an invalid pagination URL.',
        );
      }
      pageUri = parsedNextPage;
    }

    throw const SrApiException(
      'Sveriges Radio episode list is unexpectedly long.',
    );
  }

  void close() => _httpClient.close();
}
