import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/podcast_catalog.dart';
import '../domain/podcast_episode.dart';
import 'podcast_player.dart';

final podcastPlayerProvider = Provider<PodcastPlayer>((ref) {
  final player = JustAudioPodcastPlayer();
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

  Future<void> playEpisode(PodcastEpisode episode) async {
    final audioUrl = episode.audioUrl;
    if (audioUrl == null) {
      state = PlaybackState(
        episode: state.episode,
        errorMessage: 'This episode does not have a playable audio file.',
      );
      return;
    }

    state = PlaybackState(episode: episode, isLoading: true);
    final player = ref.read(podcastPlayerProvider);
    try {
      await player.setUrlAndPlay(
        audioUrl,
        id: episode.id.toString(),
        album: podcastCatalog.first.name,
        title: episode.title,
        artist: podcastCatalog.first.name,
        artUri: episode.imageUrl ?? podcastCatalog.first.imageUrl,
      );
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
      state = PlaybackState(
        episode: state.episode,
        errorMessage: 'Playback could not continue. Tap play to try again.',
      );
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await ref.read(podcastPlayerProvider).seek(position);
    } catch (error) {
      state = PlaybackState(
        episode: state.episode,
        errorMessage: 'Could not seek in this episode.',
      );
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
