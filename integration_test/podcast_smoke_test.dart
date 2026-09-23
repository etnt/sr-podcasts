import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:podcastshortcut/main.dart';
import 'package:podcastshortcut/src/podcast/audio/podcast_playback.dart';
import 'package:podcastshortcut/src/podcast/audio/podcast_player.dart';
import 'package:podcastshortcut/src/podcast/data/podcast_providers.dart';
import 'package:podcastshortcut/src/podcast/data/subscriptions.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  const fixture = <String, dynamic>{
    'episodes': [
      <String, dynamic>{
        'id': 2877969,
        'title': 'Därför platsar BRICS i Kinas världsordning',
        'description': 'Med BRICS-samarbetet som verktyg.',
        'url': 'https://www.sverigesradio.se/avsnitt/2877969',
        'publishdateutc': '/Date(1790008380000)/',
        'listenpodfile': <String, dynamic>{
          'duration': 1620,
          'url': 'https://static-cdn.sr.se/audio/episode.mp3',
        },
      },
    ],
  };

  // A stored subscription whose artwork points at an unreachable local URL
  // keeps the whole flow offline (no CDN or SR requests).
  const offlineProgram = <String, dynamic>{
    'id': 5386,
    'name': 'Radiokorrespondenterna Kina',
    'programurl': 'https://127.0.0.1:1/show',
    'programimage': 'https://127.0.0.1:1/image.jpg',
    'haspod': true,
  };
  const episodeTitle = 'Därför platsar BRICS i Kinas världsordning';
  const episodeAudioUrl = 'https://static-cdn.sr.se/audio/episode.mp3';

  testWidgets(
    'launches the app, opens the subscribed show, and plays offline',
    (tester) async {
      final fakePlayer = _FakePodcastPlayer();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('subscriptions.v1');
      await prefs.setString('subscriptions.v1', jsonEncode([offlineProgram]));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            httpClientProvider.overrideWithValue(
              MockClient((request) async => jsonResponse(fixture)),
            ),
            podcastPlayerProvider.overrideWithValue(fakePlayer),
          ],
          child: const MainApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Home lists the subscribed show; the AppBar badge shows the dev version.
      final titleTexts = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '');
      expect(titleTexts.any((text) => text.contains('SR Podcasts')), isTrue);
      expect(find.text('Radiokorrespondenterna Kina'), findsOneWidget);

      await tester.tap(find.text('Radiokorrespondenterna Kina'));
      await tester.pumpAndSettle();

      expect(find.text(episodeTitle), findsOneWidget);

      await tester.tap(find.byIcon(Icons.play_arrow).first);
      await tester.pumpAndSettle();

      expect(fakePlayer.loadedUrls, [Uri.parse(episodeAudioUrl)]);

      // Re-emit after the controls appeared and subscribed to the stream.
      fakePlayer.emitPlaying(true);
      await tester.pump();

      expect(find.byTooltip('Pause'), findsOneWidget);
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();

      expect(fakePlayer.pauseCalls, 1);
    },
  );
}
