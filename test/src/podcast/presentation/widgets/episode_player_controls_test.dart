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

/// A seeded notifier that also stubs the episode-neighbour getters and
/// records prev/next calls. The real getters read the process-wide audio
/// handler (sharedPodcastAudioHandler), which widget tests cannot install
/// without the just_audio platform fake and a fake API client, so the
/// widget-level tests stub the neighbours; the real getters and step
/// methods are covered in podcast_playback_test.dart.
class _QueueNeighboursSeededNotifier extends _SeededPlaybackNotifier {
  _QueueNeighboursSeededNotifier(
    super.initialState, {
    required this.hasPreviousEpisodeOverride,
    required this.hasNextEpisodeOverride,
  });

  final bool hasPreviousEpisodeOverride;
  final bool hasNextEpisodeOverride;

  int previousEpisodeCalls = 0;
  int nextEpisodeCalls = 0;

  @override
  bool get hasPreviousEpisode => hasPreviousEpisodeOverride;

  @override
  bool get hasNextEpisode => hasNextEpisodeOverride;

  @override
  Future<void> previousEpisode() async => previousEpisodeCalls++;

  @override
  Future<void> nextEpisode() async => nextEpisodeCalls++;
}

Future<_SeededPlaybackNotifier> _pumpControls(
  WidgetTester tester, {
  required FakePodcastPlayer player,
  required PlaybackState playbackState,
  ({bool previous, bool next})? queueNeighbours,
}) async {
  final notifier = queueNeighbours == null
      ? _SeededPlaybackNotifier(playbackState)
      : _QueueNeighboursSeededNotifier(
          playbackState,
          hasPreviousEpisodeOverride: queueNeighbours.previous,
          hasNextEpisodeOverride: queueNeighbours.next,
        );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        podcastPlayerProvider.overrideWithValue(player),
        playbackProvider.overrideWith(() => notifier),
      ],
      child: const MaterialApp(home: Scaffold(body: EpisodePlayerControls())),
    ),
  );
  // One pump flushes the fake's replayed stream values, the next renders them.
  await tester.pump();
  await tester.pump();
  return notifier;
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

  testWidgets('skip buttons seek 15 seconds in each direction', (tester) async {
    final player = FakePodcastPlayer();
    await _pumpControls(
      tester,
      player: player,
      playbackState: PlaybackState(episode: _episode()),
    );

    Finder buttonOf(String tooltip) => find.ancestor(
      of: find.byTooltip(tooltip),
      matching: find.byType(IconButton),
    );
    final backRect = tester.getRect(buttonOf('Back 15 seconds'));
    expect(backRect.width, greaterThanOrEqualTo(48));
    expect(backRect.height, greaterThanOrEqualTo(48));
    final forwardRect = tester.getRect(buttonOf('Forward 15 seconds'));
    expect(forwardRect.width, greaterThanOrEqualTo(48));
    expect(forwardRect.height, greaterThanOrEqualTo(48));

    await tester.tap(find.byTooltip('Back 15 seconds'));
    await tester.pump();
    await tester.tap(find.byTooltip('Forward 15 seconds'));
    await tester.pump();

    expect(player.seekOffsets, [
      const Duration(seconds: -15),
      const Duration(seconds: 15),
    ]);
  });

  testWidgets('skip buttons are disabled without a playable duration', (
    tester,
  ) async {
    final player = FakePodcastPlayer(initialDuration: null);
    await _pumpControls(
      tester,
      player: player,
      playbackState: PlaybackState(episode: _episode(duration: null)),
    );

    final back = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Back 15 seconds'),
        matching: find.byType(IconButton),
      ),
    );
    final forward = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Forward 15 seconds'),
        matching: find.byType(IconButton),
      ),
    );
    expect(back.onPressed, isNull);
    expect(forward.onPressed, isNull);
    expect(player.seekOffsets, isEmpty);
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

  Finder stepButtonOf(String tooltip) => find.ancestor(
    of: find.byTooltip(tooltip),
    matching: find.byType(IconButton),
  );

  testWidgets('prev/next episode buttons step between queue neighbours', (
    tester,
  ) async {
    final player = FakePodcastPlayer();
    await _pumpControls(
      tester,
      player: player,
      playbackState: PlaybackState(episode: _episode()),
      queueNeighbours: (previous: true, next: true),
    );
    // _pumpControls builds the subclass when queueNeighbours is given, and
    // the override returns that same instance.
    final notifier =
        ProviderScope.containerOf(
              tester.element(find.byType(EpisodePlayerControls)),
            ).read(playbackProvider.notifier)
            as _QueueNeighboursSeededNotifier;

    final previous = tester.widget<IconButton>(
      stepButtonOf('Previous episode'),
    );
    final next = tester.widget<IconButton>(stepButtonOf('Next episode'));
    expect(previous.onPressed, isNotNull);
    expect(next.onPressed, isNotNull);

    await tester.tap(find.byTooltip('Previous episode'));
    await tester.pump();
    await tester.tap(find.byTooltip('Next episode'));
    await tester.pump();

    expect(notifier.previousEpisodeCalls, 1);
    expect(notifier.nextEpisodeCalls, 1);
  });

  // Without the process-wide audio handler there is no published queue, so
  // the real neighbour getters report false and both buttons stay disabled.
  testWidgets('prev/next episode buttons disabled without a queue', (
    tester,
  ) async {
    final player = FakePodcastPlayer();
    await _pumpControls(
      tester,
      player: player,
      playbackState: PlaybackState(episode: _episode()),
    );

    final previous = tester.widget<IconButton>(
      stepButtonOf('Previous episode'),
    );
    final next = tester.widget<IconButton>(stepButtonOf('Next episode'));
    expect(previous.onPressed, isNull);
    expect(next.onPressed, isNull);
  });

  testWidgets('previous episode button disabled at the queue start', (
    tester,
  ) async {
    final player = FakePodcastPlayer();
    await _pumpControls(
      tester,
      player: player,
      playbackState: PlaybackState(episode: _episode()),
      queueNeighbours: (previous: false, next: true),
    );

    expect(
      tester.widget<IconButton>(stepButtonOf('Previous episode')).onPressed,
      isNull,
    );
    expect(
      tester.widget<IconButton>(stepButtonOf('Next episode')).onPressed,
      isNotNull,
    );
  });

  testWidgets('next episode button disabled at the queue end', (tester) async {
    final player = FakePodcastPlayer();
    await _pumpControls(
      tester,
      player: player,
      playbackState: PlaybackState(episode: _episode()),
      queueNeighbours: (previous: true, next: false),
    );

    expect(
      tester.widget<IconButton>(stepButtonOf('Previous episode')).onPressed,
      isNotNull,
    );
    expect(
      tester.widget<IconButton>(stepButtonOf('Next episode')).onPressed,
      isNull,
    );
  });

  testWidgets('prev/next episode buttons disabled while loading', (
    tester,
  ) async {
    final player = FakePodcastPlayer();
    await _pumpControls(
      tester,
      player: player,
      playbackState: PlaybackState(episode: _episode(), isLoading: true),
      queueNeighbours: (previous: true, next: true),
    );

    expect(
      tester.widget<IconButton>(stepButtonOf('Previous episode')).onPressed,
      isNull,
    );
    expect(
      tester.widget<IconButton>(stepButtonOf('Next episode')).onPressed,
      isNull,
    );
  });
}
