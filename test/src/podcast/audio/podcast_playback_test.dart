import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:podcastshortcut/src/podcast/audio/podcast_audio_handler.dart';
import 'package:podcastshortcut/src/podcast/audio/podcast_playback.dart';
import 'package:podcastshortcut/src/podcast/data/sr_api_client.dart';
import 'package:podcastshortcut/src/podcast/domain/podcast_episode.dart';
import 'package:podcastshortcut/src/podcast/domain/podcast_program.dart';

import '../../../fakes/fake_just_audio_platform.dart';
import '../../../fakes/fake_podcast_player.dart';

PodcastEpisode _episode() => PodcastEpisode(
  id: 2877969,
  title: 'Därför platsar BRICS i Kinas världsordning',
  audioUrl: Uri.parse('https://static-cdn.sr.se/audio/episode.mp3'),
);

PodcastEpisode _queuedEpisode(int id) => PodcastEpisode(
  id: id,
  title: 'Episode $id',
  audioUrl: Uri.parse('https://podfile.cloud/audio$id.mp3'),
);

PodcastProgram _program() => PodcastProgram(
  id: 5386,
  name: 'Radiokorrespondenterna Kina',
  pageUrl: Uri.parse('https://www.sverigesradio.se/show'),
  imageUrl: Uri.parse('https://example.com/show.png'),
  hasPod: true,
);

/// Creates the process-wide audio handler (never reset once created), so the
/// notifier's neighbour getters and step methods see a published queue.
PodcastAudioHandler _createHandlerWithQueue(PodcastEpisode episode) {
  final handler = createPodcastAudioHandler(
    apiClient: SrApiClient(
      // publishQueue seeds the episode cache, so the API is never hit.
      httpClient: MockClient(
        (request) async => http.Response(jsonEncode({'episodes': []}), 200),
      ),
    ),
    loadSubscriptions: () async => [_program()],
  );
  final episodes = [_queuedEpisode(11), _queuedEpisode(12), _queuedEpisode(13)];
  handler.publishQueue(
    episode: episode,
    program: _program(),
    episodes: episodes,
  );
  return handler;
}

ProviderContainer _container(PlaybackState initialState) {
  final container = ProviderContainer(
    overrides: [
      podcastPlayerProvider.overrideWithValue(FakePodcastPlayer()),
      playbackProvider.overrideWith(
        () => _SeededPlaybackNotifier(initialState),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  JustAudioPlatform.instance = FakeJustAudioPlatform();

  // previousEpisode/nextEpisode resolve the process-wide audio handler. This
  // test must stay first: the tests below call createPodcastAudioHandler,
  // which sets the handler global and never resets it.
  test('episode stepping is a no-op without the audio handler', () async {
    final episode = _episode();
    final container = _container(PlaybackState(episode: episode));
    final notifier = container.read(playbackProvider.notifier);

    expect(notifier.hasPreviousEpisode, isFalse);
    expect(notifier.hasNextEpisode, isFalse);

    await notifier.previousEpisode();
    await notifier.nextEpisode();

    final state = container.read(playbackProvider);
    expect(state.episode, same(episode));
    expect(state.isLoading, isFalse);
    expect(state.errorMessage, isNull);
  });

  group('episode stepping with a published queue', () {
    // These tests create the process-wide audio handler, so they must run
    // after the no-handler test above (the global is never reset).
    test('nextEpisode steps to the following episode', () async {
      final handler = _createHandlerWithQueue(_queuedEpisode(12));
      final container = _container(PlaybackState(episode: _queuedEpisode(12)));
      final notifier = container.read(playbackProvider.notifier);

      expect(notifier.hasPreviousEpisode, isTrue);
      expect(notifier.hasNextEpisode, isTrue);

      await notifier.nextEpisode();

      final state = container.read(playbackProvider);
      expect(state.episode?.id, 13);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
      expect(handler.playbackState.value.queueIndex, 2);
    });

    test('previousEpisode steps to the preceding episode', () async {
      final handler = _createHandlerWithQueue(_queuedEpisode(12));
      final container = _container(PlaybackState(episode: _queuedEpisode(12)));
      final notifier = container.read(playbackProvider.notifier);

      await notifier.previousEpisode();

      final state = container.read(playbackProvider);
      expect(state.episode?.id, 11);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
      expect(handler.playbackState.value.queueIndex, 0);
    });

    test('nextEpisode at the queue end is a no-op', () async {
      final handler = _createHandlerWithQueue(_queuedEpisode(13));
      final container = _container(PlaybackState(episode: _queuedEpisode(13)));
      final notifier = container.read(playbackProvider.notifier);

      expect(notifier.hasNextEpisode, isFalse);

      await notifier.nextEpisode();

      final state = container.read(playbackProvider);
      expect(state.episode?.id, 13);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
      expect(handler.playbackState.value.queueIndex, 2);
    });
  });

  // A failed skip while an episode is still loading must keep the loading
  // flag, otherwise the play button re-enables and taps while the real load
  // is in flight.
  test('a failed skip preserves isLoading and reports the error', () async {
    final player = FakePodcastPlayer()..failOnSeekRelative = true;
    final episode = _episode();
    final container = ProviderContainer(
      overrides: [
        podcastPlayerProvider.overrideWithValue(player),
        playbackProvider.overrideWith(
          () => _SeededPlaybackNotifier(
            PlaybackState(episode: episode, isLoading: true),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(playbackProvider.notifier).skipForward();

    final state = container.read(playbackProvider);
    expect(state.isLoading, isTrue);
    expect(state.episode, same(episode));
    expect(state.errorMessage, 'Could not seek in this episode.');
    expect(player.seekOffsets, isEmpty);
  });

  // Tapping an episode without audio while another episode is still loading
  // must keep the loading flag, otherwise the play button re-enables for the
  // in-flight episode.
  test('playing an episode without audio preserves isLoading', () async {
    final player = FakePodcastPlayer();
    final loadingEpisode = _episode();
    final brokenEpisode = PodcastEpisode(
      id: 2877970,
      title: 'Utan ljudfil',
      audioUrl: null,
    );
    final container = ProviderContainer(
      overrides: [
        podcastPlayerProvider.overrideWithValue(player),
        playbackProvider.overrideWith(
          () => _SeededPlaybackNotifier(
            PlaybackState(episode: loadingEpisode, isLoading: true),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(playbackProvider.notifier).playEpisode(brokenEpisode);

    final state = container.read(playbackProvider);
    expect(state.isLoading, isTrue);
    expect(state.episode, same(loadingEpisode));
    expect(
      state.errorMessage,
      'This episode does not have a playable audio file.',
    );
    expect(player.loadedUrls, isEmpty);
  });
}

class _SeededPlaybackNotifier extends PlaybackNotifier {
  _SeededPlaybackNotifier(this.initialState);

  final PlaybackState initialState;

  @override
  PlaybackState build() => initialState;
}
