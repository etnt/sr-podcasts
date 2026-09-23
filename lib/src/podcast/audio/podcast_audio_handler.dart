import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../data/sr_api_client.dart';
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
/// the media notification on the phone today, and Android Auto from Phase 2.
class PodcastAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  PodcastAudioHandler({
    required this.apiClient,
    required this.loadSubscriptions,
  }) {
    _player.playbackEventStream.listen(_broadcastState);
  }

  /// The SR data source for the Phase 2 browse tree.
  final SrApiClient apiClient;

  /// Loads the saved subscriptions for the Phase 2 browse tree.
  final Future<List<PodcastProgram>> Function() loadSubscriptions;

  final AudioPlayer _player = AudioPlayer();

  /// The single player owned by the handler. The phone UI reaches it only
  /// through [AudioServicePodcastPlayer]; the car reaches it through the
  /// callbacks of this handler.
  AudioPlayer get player => _player;

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  /// Maps the current just_audio event onto the audio_service playback state
  /// that the media notification and Android Auto read.
  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
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
        queueIndex: event.currentIndex,
      ),
    );
  }
}
