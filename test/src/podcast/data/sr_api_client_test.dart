import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:podcastshortcut/src/podcast/data/podcast_catalog.dart';
import 'package:podcastshortcut/src/podcast/data/sr_api_client.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/radiokorrespondenterna_kina_episodes.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  // Builds UTF-8 JSON responses the way the real SR API serves them.
  http.Response jsonResponse(Object json) => http.Response.bytes(
    utf8.encode(jsonEncode(json)),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  group('SrApiClient.fetchEpisodes', () {
    test('parses actual SR fixture and follows API pagination', () async {
      final requested = <Uri>[];
      final client = SrApiClient(
        httpClient: MockClient((request) async {
          requested.add(request.url);
          if (requested.length == 1) {
            return http.Response(
              jsonEncode({
                'episodes': (fixture['episodes'] as List<dynamic>),
                'pagination': {
                  'nextpage':
                      'https://api.sr.se/v2/episodes/index?programid=5386&format=json&page=2',
                },
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response(
            jsonEncode({'episodes': []}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(client.close);

      final episodes = await client.fetchEpisodes(podcastCatalog.first);

      expect(episodes, hasLength(1));
      expect(
        episodes.first.title,
        'Därför platsar BRICS i Kinas världsordning',
      );
      expect(episodes.first.isPlayable, isTrue);
      expect(requested, hasLength(2));
      expect(requested.first.queryParameters['programid'], '5386');
      expect(requested.last.path, '/v2/episodes/index');
    });

    test('returns empty response without pagination', () async {
      final client = SrApiClient(
        httpClient: MockClient(
          (request) async => http.Response('{"episodes":[]}', 200),
        ),
      );
      addTearDown(client.close);

      expect(await client.fetchEpisodes(podcastCatalog.first), isEmpty);
    });

    test('exposes HTTP errors to the caller', () async {
      final client = SrApiClient(
        httpClient: MockClient(
          (request) async => http.Response('unavailable', 503),
        ),
      );
      addTearDown(client.close);

      expect(
        () => client.fetchEpisodes(podcastCatalog.first),
        throwsA(isA<SrApiException>()),
      );
    });

    test('rejects malformed JSON and malformed episode records', () async {
      for (final body in ['not json', '{"unexpected":[]}']) {
        final client = SrApiClient(
          httpClient: MockClient((request) async => http.Response(body, 200)),
        );
        addTearDown(client.close);
        await expectLater(
          client.fetchEpisodes(podcastCatalog.first),
          throwsA(isA<SrApiException>()),
        );
      }

      final client = SrApiClient(
        httpClient: MockClient(
          (request) async => http.Response('{"episodes":[{"id":1}]}', 200),
        ),
      );
      addTearDown(client.close);
      await expectLater(
        client.fetchEpisodes(podcastCatalog.first),
        throwsA(isA<SrApiException>()),
      );
    });

    test('rejects unsafe pagination links', () async {
      final client = SrApiClient(
        httpClient: MockClient(
          (request) async => http.Response(
            '{"episodes":[],"pagination":{"nextpage":"https://example.com/next"}}',
            200,
          ),
        ),
      );
      addTearDown(client.close);

      await expectLater(
        client.fetchEpisodes(podcastCatalog.first),
        throwsA(isA<SrApiException>()),
      );
    });
  });

  group('SrApiClient.fetchAllPrograms', () {
    test(
      'parses the program corpus fixture and skips malformed entries',
      () async {
        final corpusFixture =
            jsonDecode(
                  File('test/fixtures/sr_programs.json').readAsStringSync(),
                )
                as Map<String, dynamic>;
        final client = SrApiClient(
          httpClient: MockClient(
            (request) async => jsonResponse(corpusFixture),
          ),
        );
        addTearDown(client.close);

        final programs = await client.fetchAllPrograms();

        expect(programs, hasLength(4));
        expect(programs.first.id, 5386);
        expect(programs.first.name, 'Radiokorrespondenterna Kina');
        expect(programs.first.hasPod, isTrue);
        expect(
          programs.first.description,
          contains('maktspelet mellan öst och väst'),
        );
        expect(programs[1].imageUrl, isNull);
        expect(programs.where((program) => program.hasPod), hasLength(3));
      },
    );

    test('surfaces HTTP errors to the caller', () async {
      final client = SrApiClient(
        httpClient: MockClient((request) async => http.Response('down', 503)),
      );
      addTearDown(client.close);

      expect(() => client.fetchAllPrograms(), throwsA(isA<SrApiException>()));
    });

    test('rejects malformed JSON and missing program lists', () async {
      for (final body in ['not json', '{"unexpected":[]}']) {
        final client = SrApiClient(
          httpClient: MockClient((request) async => http.Response(body, 200)),
        );
        addTearDown(client.close);
        await expectLater(
          client.fetchAllPrograms(),
          throwsA(isA<SrApiException>()),
        );
      }
    });
  });
}
