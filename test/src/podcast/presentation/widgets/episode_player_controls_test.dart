import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podcastshortcut/src/podcast/audio/podcast_playback.dart';
import 'package:podcastshortcut/src/podcast/domain/podcast_episode.dart';
import 'package:podcastshortcut/src/podcast/presentation/widgets/episode_player_controls.dart';

import '../../../../fakes/fake_podcast_player.dart';

Uri _audioUrl() => Uri.parse('https://static-cdn.sr.se/audio/episode.mp3');

PodcastEpisode _episode({Duration? duration}) => PodcastEpisode(
  id: 2877969,
  title: 'Därför platsar BRICS i Kinas världsordning',
  description: 'Med BRICS-samarbetet som verktyg.',
  publishedAt: DateTime(2026, 9, 18),
  audioUrl: _audioUrl(),
  duration: duration,
);

class _SeededPlaybackNotifier extends PlaybackNotifier {
  _SeededPlaybackNotifier(this.initialState);

  final PlaybackState initialState;

  @override
  PlaybackState build() => initialState;
}

Future<void> _pumpControls(
  WidgetTester tester, {
  required FakePodcastPlayer player,
  required PlaybackState playbackState,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        podcastPlayerProvider.overrideWithValue(player),
        playbackProvider.overrideWith(
          () => _SeededPlaybackNotifier(playbackState),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: EpisodePlayerControls())),
    ),
  );
  // One pump flushes the fake's replayed stream values, the next renders them.
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('shows playing state, duration, and pauses on tap', (
    tester,
  ) async {
    final player = FakePodcastPlayer();
    final episode = _episode();
    await _pumpControls(
      tester,
      player: player,
      playbackState: PlaybackState(episode: episode),
    );

    expect(find.text(episode.title), findsOneWidget);
    expect(find.byTooltip('Play'), findsOneWidget);
    expect(find.text('27:03'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);

    player.emitPlaying(true);
    player.emitPosition(const Duration(seconds: 90));
    await tester.pump();

    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(find.text('1:30'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();

    expect(player.pauseCalls, 1);
    expect(player.playCalls, 0);
  });

  testWidgets('disabled slider and duration placeholder without duration', (
    tester,
  ) async {
    final player = FakePodcastPlayer(initialDuration: null);
    await _pumpControls(
      tester,
      player: player,
      playbackState: PlaybackState(episode: _episode(duration: null)),
    );

    expect(find.text('--:--'), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.onChanged, isNull);
  });

  testWidgets('disabled controls while loading', (tester) async {
    final player = FakePodcastPlayer();
    await _pumpControls(
      tester,
      player: player,
      playbackState: PlaybackState(episode: _episode(), isLoading: true),
    );

    expect(find.byTooltip('Loading episode'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byType(CircularProgressIndicator),
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('shows error message and retries through the player', (
    tester,
  ) async {
    final player = FakePodcastPlayer();
    await _pumpControls(
      tester,
      player: player,
      playbackState: PlaybackState(
        episode: _episode(),
        errorMessage:
            'Unable to play this episode. Check your connection and retry.',
      ),
    );

    expect(
      find.text(
        'Unable to play this episode. Check your connection and retry.',
      ),
      findsOneWidget,
    );
    expect(player.loadedUrls, isEmpty);

    await tester.tap(find.byTooltip('Play'));
    await tester.pump();

    expect(player.loadedUrls, [_audioUrl()]);
  });

  testWidgets('delegates seek requests to the player', (tester) async {
    final player = FakePodcastPlayer();
    await _pumpControls(
      tester,
      player: player,
      playbackState: PlaybackState(episode: _episode()),
    );

    await tester.tap(find.byType(Slider));
    await tester.pump();

    expect(player.seekPositions, hasLength(1));
    final maxDuration = const Duration(minutes: 27, seconds: 3);
    expect(
      player.seekPositions.single.inMilliseconds,
      inInclusiveRange(0, maxDuration.inMilliseconds),
    );
  });
}
