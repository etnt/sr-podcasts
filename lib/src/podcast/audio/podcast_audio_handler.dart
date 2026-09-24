import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../data/sr_api_client.dart';
import '../domain/podcast_episode.dart';
import '../domain/podcast_program.dart';

/// The process-wide handler instance, created once in `main()` before
/// `runApp` because `AudioService.init` needs it and the Riverpod scope does
/// not exist yet at that point.
PodcastAudioHandler? _sharedHandler;

/// Creates the process-wide [PodcastAudioHandler] and remembers it as the
/// instance that [sharedPodcastAudioHandler] returns.
PodcastAudioHandler createPodcastAudioHandler({
  required SrApiClient apiClient,
  required Future<List<PodcastProgram>> Function() loadSubscriptions,
}) {
  final handler = PodcastAudioHandler(
    apiClient: apiClient,
    loadSubscriptions: loadSubscriptions,
  );
  _sharedHandler = handler;
  return handler;
}

/// The handler created by [createPodcastAudioHandler].
PodcastAudioHandler get sharedPodcastAudioHandler {
  final handler = _sharedHandler;
  if (handler == null) {
    throw StateError(
      'createPodcastAudioHandler must run in main() before the player is used.',
    );
  }
  return handler;
}

/// Owns the [AudioPlayer] and publishes its state to system media clients:
/// the media notification on the phone, and the Android Auto browse and
/// player screens in the car.
class PodcastAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  /// Media id of the browse tree root.
  static const rootId = 'root';

  static const _showIdPrefix = 'show:';
  static const _episodeIdPrefix = 'episode:';

  /// `CONTENT_STYLE` hints for the browse root: Android Auto renders shows
  /// as a grid and episodes as a list.
  static const androidBrowsableRootExtras = <String, dynamic>{
    AndroidContentStyle.supportedKey: true,
    AndroidContentStyle.browsableHintKey: AndroidContentStyle.gridItemHintValue,
    AndroidContentStyle.playableHintKey: AndroidContentStyle.listItemHintValue,
  };

  static const _browsableItemExtras = <String, dynamic>{
    AndroidContentStyle.supportedKey: true,
    AndroidContentStyle.browsableHintKey: AndroidContentStyle.gridItemHintValue,
  };

  static const _playableItemExtras = <String, dynamic>{
    AndroidContentStyle.supportedKey: true,
    AndroidContentStyle.playableHintKey: AndroidContentStyle.listItemHintValue,
  };

  /// Creates the handler. [player] exists only for tests, which inject an
  /// [AudioPlayer] built against a fake [JustAudioPlatform]; production
  /// callers get the default platform-backed player.
  PodcastAudioHandler({
    required this.apiClient,
    required this.loadSubscriptions,
    @visibleForTesting AudioPlayer? player,
  }) : _player = player ?? AudioPlayer() {
    _player.playbackEventStream.listen(_broadcastState);
  }

  /// The SR data source for the Phase 2 browse tree.
  final SrApiClient apiClient;

  /// Loads the saved subscriptions for the Phase 2 browse tree.
  final Future<List<PodcastProgram>> Function() loadSubscriptions;

  final AudioPlayer _player;

  /// Latest episodes per show, fetched lazily on first browse.
  final Map<int, List<PodcastEpisode>> _episodeCache = {};

  /// Maps episode media ids to the episode and its show, so the car can
  /// resolve a picked item without re-fetching the browse tree.
  final Map<String, (PodcastEpisode, PodcastProgram)> _episodeIndex = {};

  /// Test visibility into the media-id index that the browse tree builds.
  @visibleForTesting
  Map<String, (PodcastEpisode, PodcastProgram)> get episodeIndex =>
      _episodeIndex;

  /// Index of the current item within the published queue. The player's own
  /// sequence index is unreliable for the phone path, which loads a single
  /// source, so the handler tracks it itself.
  int _queueIndex = 0;

  /// The single player owned by the handler. The phone UI reaches it only
  /// through [AudioServicePodcastPlayer]; the car reaches it through the
  /// callbacks of this handler.
  AudioPlayer get player => _player;

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    try {
      final programs = await loadSubscriptions();
      if (parentMediaId == rootId) {
        return [for (final program in programs) _programToMediaItem(program)];
      }
      if (!parentMediaId.startsWith(_showIdPrefix)) return const [];
      final program = _programFor(parentMediaId, programs);
      if (program == null) return const [];
      return [
        for (final episode in await _episodesFor(program))
          if (episode.isPlayable) _episodeToMediaItem(episode, program),
      ];
    } catch (error) {
      // A failed browse must never crash the car's browse screen.
      debugPrint(
        'PodcastAudioHandler: browse failed for $parentMediaId: $error',
      );
      return const [];
    }
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    final indexed = _episodeIndex[mediaItem.id];
    if (indexed == null) return;
    await _playEpisode(indexed.$1, indexed.$2);
  }

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    final indexed = _episodeIndex[mediaId];
    if (indexed == null) return;
    await _playEpisode(indexed.$1, indexed.$2);
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  /// The single playback path shared by the car callbacks and, through
  /// [AudioServicePodcastPlayer], the phone UI: publishes the show's playable
  /// episodes as the queue and starts at the chosen episode. Only the selected
  /// URL is loaded into just_audio; the audio_service queue supplies car
  /// navigation. This keeps the Android Auto callback fast even for shows with
  /// hundreds of episodes.
  Future<void> _playEpisode(
    PodcastEpisode episode,
    PodcastProgram program, {
    bool autoplay = true,
  }) async {
    final audioUrl = episode.audioUrl;
    if (audioUrl == null) return;
    var playable = await _playableEpisodes(program);
    if (!playable.any((candidate) => candidate.id == episode.id)) {
      playable = [episode];
    }
    final mediaItems = [
      for (final candidate in playable) _episodeToMediaItem(candidate, program),
    ];
    final currentIndex = playable.indexWhere(
      (candidate) => candidate.id == episode.id,
    );
    _queueIndex = currentIndex < 0 ? 0 : currentIndex;
    queue.add(mediaItems);
    queueTitle.add(program.name);
    mediaItem.add(mediaItems[_queueIndex]);
    playbackState.add(playbackState.value.copyWith(queueIndex: _queueIndex));
    await _player.stop();
    await _player.setAudioSource(AudioSource.uri(audioUrl), preload: false);
    if (autoplay) unawaited(_startPlayback());
  }

  /// Publishes the show's episode list as the current queue around the
  /// already-loaded [episode] so remote controllers (Android Auto) can step
  /// between episodes when playback was started on the phone. Never touches
  /// the player; the episode is already loaded and playing.
  Future<void> publishQueue({
    required PodcastEpisode episode,
    required PodcastProgram program,
    required List<PodcastEpisode> episodes,
  }) async {
    _episodeCache.putIfAbsent(program.id, () => episodes);
    final playable = [
      for (final candidate in episodes)
        if (candidate.isPlayable) candidate,
    ];
    final index = playable.indexWhere(
      (candidate) => candidate.id == episode.id,
    );
    if (index < 0) return;
    final mediaItems = [
      for (final candidate in playable) _episodeToMediaItem(candidate, program),
    ];
    _queueIndex = index;
    queue.add(mediaItems);
    queueTitle.add(program.name);
    mediaItem.add(mediaItems[index]);
    playbackState.add(playbackState.value.copyWith(queueIndex: _queueIndex));
  }

  @override
  Future<void> play() async {
    unawaited(_startPlayback());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> playFromSearch(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return;
    try {
      PodcastProgram? match;
      for (final program in await loadSubscriptions()) {
        if (program.name.toLowerCase().contains(needle)) {
          match = program;
          break;
        }
      }
      if (match == null) return;
      final playable = await _playableEpisodes(match);
      if (playable.isEmpty) return;
      await _playEpisode(playable.first, match);
    } catch (error) {
      debugPrint('PodcastAudioHandler: search failed for "$query": $error');
    }
  }

  /// Steps to the queue item at [index]. The stock [QueueHandler] computes
  /// the target index for skipToNext/skipToPrevious and delegates here.
  @override
  Future<void> skipToQueueItem(int index) async {
    final items = queue.value;
    if (index < 0 || index >= items.length) return;
    final indexed = _episodeIndex[items[index].id];
    if (indexed == null) return;
    final wasPlaying = _player.playing;
    await _playEpisode(indexed.$1, indexed.$2, autoplay: wasPlaying);
    await super.skipToQueueItem(index);
  }

  PodcastProgram? _programFor(String mediaId, List<PodcastProgram> programs) {
    final programId = int.tryParse(mediaId.substring(_showIdPrefix.length));
    if (programId == null) return null;
    for (final program in programs) {
      if (program.id == programId) return program;
    }
    return null;
  }

  /// Latest episodes of [program], fetched once and cached per show.
  Future<List<PodcastEpisode>> _episodesFor(PodcastProgram program) async {
    final cached = _episodeCache[program.id];
    if (cached != null) return cached;
    // The car only needs the latest episodes. Fetching every historical page
    // can exceed Android Auto's browse timeout for long-running shows.
    final episodes = await apiClient.fetchEpisodes(program, pageLimit: 1);
    return _episodeCache[program.id] = episodes;
  }

  /// The playable episodes of [program], fetching them if not cached.
  Future<List<PodcastEpisode>> _playableEpisodes(PodcastProgram program) =>
      _episodesFor(program).then(
        (episodes) => [
          for (final episode in episodes)
            if (episode.isPlayable) episode,
        ],
      );

  MediaItem _programToMediaItem(PodcastProgram program) => MediaItem(
    id: '$_showIdPrefix${program.id}',
    album: 'SR Podcasts',
    title: program.name,
    artUri: program.imageUrl,
    playable: false,
    extras: _browsableItemExtras,
  );

  MediaItem _episodeToMediaItem(
    PodcastEpisode episode,
    PodcastProgram program,
  ) {
    final id = '$_episodeIdPrefix${episode.id}';
    _episodeIndex[id] = (episode, program);
    return MediaItem(
      id: id,
      album: program.name,
      title: episode.title,
      artist: program.name,
      artUri: episode.imageUrl ?? program.imageUrl,
      duration: episode.duration,
      playable: true,
      extras: _playableItemExtras,
    );
  }

  /// Maps the current just_audio event onto the audio_service playback state
  /// that the media notification and Android Auto read.
  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    final hasPrevious = _queueIndex > 0;
    final hasNext = _queueIndex + 1 < queue.value.length;
    final controls = [
      if (hasPrevious) MediaControl.skipToPrevious,
      if (playing) MediaControl.pause else MediaControl.play,
      if (hasNext) MediaControl.skipToNext,
    ];
    playbackState.add(
      playbackState.value.copyWith(
        controls: controls,
        androidCompactActionIndices: [
          for (var index = 0; index < controls.length && index < 3; index++)
            index,
        ],
        systemActions: const {MediaAction.seek},
        processingState: switch (_player.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _queueIndex,
      ),
    );
  }

  Future<void> _startPlayback() async {
    try {
      await _player.play();
    } catch (error) {
      debugPrint('PodcastAudioHandler: playback failed: $error');
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
          playing: false,
          errorCode: 1,
          errorMessage: 'Unable to play this episode.',
        ),
      );
    }
  }
}
