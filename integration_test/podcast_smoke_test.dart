import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:podcastshortcut/src/podcast/audio/podcast_playback.dart';
import 'package:podcastshortcut/src/podcast/audio/podcast_player.dart';
import 'package:podcastshortcut/src/podcast/data/podcast_catalog.dart';
import 'package:podcastshortcut/src/podcast/data/podcast_providers.dart';
import 'package:podcastshortcut/src/podcast/domain/podcast_program.dart';
import 'package:podcastshortcut/src/podcast/presentation/podcast_screen.dart';

/// Offline fake used by the integration smoke test. Kept in this file
/// because integration tests cannot import helpers from `test/`.
class _FakePodcastPlayer implements PodcastPlayer {
  final loadedUrls = <Uri>[];
  int playCalls = 0;
  int pauseCalls = 0;

  @override
  bool playing = false;

  final _playing = StreamController<bool>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<Duration?> get durationStream => _duration.stream;

  void emitPlaying(bool value) => _playing.add(value);

  @override
  Future<void> setUrlAndPlay(
    Uri audioUrl, {
    required String id,
    required String album,
    required String title,
    String? artist,
    Uri? artUri,
  }) async {
    loadedUrls.add(audioUrl);
    playing = true;
    emitPlaying(true);
    _duration.add(const Duration(minutes: 27));
  }

  @override
  Future<void> play() async {
    playCalls++;
    playing = true;
    emitPlaying(true);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    playing = false;
    emitPlaying(false);
  }

  @override
  Future<void> seek(Duration position) async {
    _position.add(position);
  }

  @override
  Future<void> dispose() async {
    await _playing.close();
    await _position.close();
    await _duration.close();
  }
}

/// Builds a UTF-8 JSON response the way the real SR API serves them.
http.Response jsonResponse(Object json) => http.Response.bytes(
  utf8.encode(jsonEncode(json)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Inlined (instead of read from disk) because this test runs on the device.
  // Values mirror the sanitized fixture in test/fixtures/.
  const fixture = <String, dynamic>{
    'episodes': [
      <String, dynamic>{
        'id': 2877969,
        'title': 'Därför platsar BRICS i Kinas världsordning',
        'description':
            'Med BRICS-samarbetet som verktyg vill Kina flytta fram sina '
            'globala positioner.',
        'url': 'https://www.sverigesradio.se/avsnitt/2877969',
        'publishdateutc': '/Date(1790008380000)/',
        'imageurl':
            'https://static-cdn.sr.se/images/5386/62b8a260-203f-4d38-bbea-8ee9244137c1.jpg'
            '?preset=api-default-square',
        'listenpodfile': <String, dynamic>{
          'duration': 1620,
          'url':
              'https://static-cdn.sr.se/laddahem/podradio/2026/09/'
              'radiokorrespondenterna_kina_darfor_platsar_brics_i_kinas_v_20260918_1502506642.mp3',
        },
      },
    ],
  };
  final episodeTitle =
      ((fixture['episodes'] as List<dynamic>).first
              as Map<String, dynamic>)['title']
          as String;
  final episodeAudioUrl = Uri.parse(
    (((fixture['episodes'] as List<dynamic>).first
                as Map<String, dynamic>)['listenpodfile']
            as Map<String, dynamic>)['url']
        as String,
  );

  testWidgets('shows the hardcoded show and plays an episode via fake player', (
    tester,
  ) async {
    final fakePlayer = _FakePodcastPlayer();
    // Use the real hardcoded program but replace its CDN image with a local
    // unreachable URL so the test makes no external network requests.
    final program = PodcastProgram(
      id: podcastCatalog.first.id,
      name: podcastCatalog.first.name,
      pageUrl: podcastCatalog.first.pageUrl,
      imageUrl: Uri.parse('https://127.0.0.1:1/unavailable.jpg'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          httpClientProvider.overrideWithValue(
            MockClient((request) async => jsonResponse(fixture)),
          ),
          podcastPlayerProvider.overrideWithValue(fakePlayer),
        ],
        child: MaterialApp(home: PodcastScreen(program: program)),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Radiokorrespondenterna Kina'), findsOneWidget);
    expect(find.text(episodeTitle), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow).first);
    await tester.pumpAndSettle();

    expect(fakePlayer.loadedUrls, [episodeAudioUrl]);

    // Re-emit after the controls appeared and subscribed to the stream.
    fakePlayer.emitPlaying(true);
    await tester.pump();

    expect(find.byTooltip('Pause'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();

    expect(fakePlayer.pauseCalls, 1);
  });
}
