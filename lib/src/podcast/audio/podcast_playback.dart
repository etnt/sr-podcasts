import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/podcast_catalog.dart';
import '../domain/podcast_episode.dart';
import '../domain/podcast_program.dart';
import 'podcast_audio_handler.dart';
import 'podcast_player.dart';

final podcastPlayerProvider = Provider<PodcastPlayer>((ref) {
  final player = AudioServicePodcastPlayer(sharedPodcastAudioHandler);
  ref.onDispose(player.dispose);
  return player;
});

final playbackProvider = NotifierProvider<PlaybackNotifier, PlaybackState>(
  PlaybackNotifier.new,
);

class PlaybackState {
  const PlaybackState({
    this.episode,
    this.isLoading = false,
    this.errorMessage,
  });

  final PodcastEpisode? episode;
  final bool isLoading;
  final String? errorMessage;
}

class PlaybackNotifier extends Notifier<PlaybackState> {
  @override
  PlaybackState build() => const PlaybackState();

  /// Plays [episode]. When [program] and [queue] are given, the show's
  /// episode list is published as the playback queue so remote controllers
  /// such as Android Auto can step between episodes.
  Future<void> playEpisode(
    PodcastEpisode episode, {
    PodcastProgram? program,
    List<PodcastEpisode>? queue,
  }) async {
    final audioUrl = episode.audioUrl;
    if (audioUrl == null) {
      state = _errorState('This episode does not have a playable audio file.');
      return;
    }

    state = PlaybackState(episode: episode, isLoading: true);
    final player = ref.read(podcastPlayerProvider);
    final show = program ?? podcastCatalog.first;
    try {
      await player.setUrlAndPlay(
        audioUrl,
        id: episode.id.toString(),
        album: show.name,
        title: episode.title,
        artist: show.name,
        artUri: episode.imageUrl ?? show.imageUrl,
      );
      if (program != null && queue != null) {
        await player.publishQueue(
          episode: episode,
          program: program,
          episodes: queue,
        );
      }
      state = PlaybackState(episode: episode);
      // play() completes when the media item ends; it should not block the UI.
      unawaited(_startPlayback(player, episode));
    } catch (error) {
      state = PlaybackState(
        episode: episode,
        errorMessage:
            'Unable to play this episode. Check your connection and retry.',
      );
    }
  }

  Future<void> togglePlayback() async {
    final player = ref.read(podcastPlayerProvider);
    try {
      if (player.playing) {
        await player.pause();
      } else if (state.episode != null) {
        await player.play();
      }
    } catch (error) {
      state = _errorState(
        'Playback could not continue. Tap play to try again.',
      );
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await ref.read(podcastPlayerProvider).seek(position);
    } catch (error) {
      state = _errorState('Could not seek in this episode.');
    }
  }

  /// A failed operation keeps the episode and the loading flag, so a failure
  /// while an episode is still loading does not re-enable the play button.
  PlaybackState _errorState(String message) => PlaybackState(
    episode: state.episode,
    isLoading: state.isLoading,
    errorMessage: message,
  );

  /// Jumps 15 seconds back in the current episode.
  Future<void> skipBackward() => _skip(-PodcastAudioHandler.skipInterval);

  /// Jumps 15 seconds forward in the current episode.
  Future<void> skipForward() => _skip(PodcastAudioHandler.skipInterval);

  /// Whether the published queue holds an episode before the current one.
  /// Returns false when the audio handler has not been created yet, which
  /// is the case in widget tests that seed this notifier directly.
  bool get hasPreviousEpisode => _hasNeighbour(-1);

  /// Whether the published queue holds an episode after the current one.
  bool get hasNextEpisode => _hasNeighbour(1);

  bool _hasNeighbour(int delta) {
    final handler = _handlerOrNull();
    if (handler == null) return false;
    final target = (handler.playbackState.value.queueIndex ?? 0) + delta;
    final queue = handler.queue.value;
    return target >= 0 && target < queue.length;
  }

  /// Steps to the previous episode in the published queue, if any. The
  /// handler republishes the queue around the new episode and keeps the
  /// playing state, so the media session follows the change.
  Future<void> previousEpisode() => _stepEpisode(-1);

  /// Steps to the next episode in the published queue, if any.
  /// See [previousEpisode].
  Future<void> nextEpisode() => _stepEpisode(1);

  Future<void> _stepEpisode(int delta) async {
    final handler = _handlerOrNull();
    if (handler == null) return;
    final queue = handler.queue.value;
    final target = (handler.playbackState.value.queueIndex ?? 0) + delta;
    if (target < 0 || target >= queue.length) return;
    final indexed = handler.episodeForMediaId(queue[target].id);
    if (indexed == null) return;
    final (episode, _) = indexed;
    state = PlaybackState(episode: episode, isLoading: true);
    try {
      await handler.skipToQueueItem(target);
      state = PlaybackState(episode: episode);
    } catch (error) {
      state = PlaybackState(
        episode: episode,
        errorMessage: 'Could not play this episode. Tap play to try again.',
      );
    }
  }

  PodcastAudioHandler? _handlerOrNull() {
    try {
      return sharedPodcastAudioHandler;
    } on StateError {
      // createPodcastAudioHandler has not run, so there is no queue to
      // step through.
      return null;
    }
  }

  Future<void> _skip(Duration offset) async {
    if (state.episode == null) return;
    try {
      await ref.read(podcastPlayerProvider).seekRelative(offset);
    } catch (error) {
      // Keep the loading flag so a failed skip while an episode is still
      // loading does not re-enable the play button.
      state = _errorState('Could not seek in this episode.');
    }
  }

  Future<void> retry() async {
    final episode = state.episode;
    if (episode != null) await playEpisode(episode);
  }

  Future<void> _startPlayback(
    PodcastPlayer player,
    PodcastEpisode episode,
  ) async {
    try {
      await player.play();
    } catch (error) {
      state = PlaybackState(
        episode: episode,
        errorMessage:
            'Unable to play this episode. Check your connection and retry.',
      );
    }
  }
}

Future<void> configurePodcastAudioSession() async {
  final session = await AudioSession.instance;
  await session.configure(AudioSessionConfiguration.speech());
}
