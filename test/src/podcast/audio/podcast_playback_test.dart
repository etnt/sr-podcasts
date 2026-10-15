import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podcastshortcut/src/podcast/audio/podcast_playback.dart';
import 'package:podcastshortcut/src/podcast/domain/podcast_episode.dart';

import '../../../fakes/fake_podcast_player.dart';

PodcastEpisode _episode() => PodcastEpisode(
  id: 2877969,
  title: 'Därför platsar BRICS i Kinas världsordning',
  audioUrl: Uri.parse('https://static-cdn.sr.se/audio/episode.mp3'),
);

void main() {
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
