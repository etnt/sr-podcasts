import 'dart:async';

import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

/// just_audio's AudioPlayer binds to platform channels at construction.
/// This fake lets tests create real AudioPlayer objects without native
/// audio; the logic under test never loads actual audio. Shared by
/// podcast_audio_handler_test.dart and podcast_playback_test.dart.
class FakeJustAudioPlatform extends JustAudioPlatform {
  final players = <FakeAudioPlayerPlatform>[];

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final player = FakeAudioPlayerPlatform(request.id);
    players.add(player);
    return player;
  }
}

class FakeAudioPlayerPlatform extends AudioPlayerPlatform {
  FakeAudioPlayerPlatform(super.id);

  final playCompleter = Completer<PlayResponse>();

  final _events = StreamController<PlaybackEventMessage>.broadcast();

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  /// Publishes a playback event the way the real platform does. [duration]
  /// gives the player its duration, which the handler's jumps clamp against.
  void emitEvent({required Duration updatePosition, Duration? duration}) =>
      _events.add(
        PlaybackEventMessage(
          processingState: ProcessingStateMessage.ready,
          updateTime: DateTime.now(),
          updatePosition: updatePosition,
          bufferedPosition: updatePosition,
          duration: duration,
          icyMetadata: null,
          currentIndex: 0,
          androidAudioSessionId: null,
        ),
      );

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    // Report ready with the duration, as a real platform would, so the load
    // completes and the player knows the audio length.
    emitEvent(
      updatePosition: Duration.zero,
      duration: const Duration(minutes: 10),
    );
    return LoadResponse(duration: const Duration(minutes: 10));
  }

  @override
  Future<PlayResponse> play(PlayRequest request) => playCompleter.future;

  @override
  Future<PauseResponse> pause(PauseRequest request) async => PauseResponse();

  @override
  Future<SeekResponse> seek(SeekRequest request) async => SeekResponse();

  // No-ops for the setters just_audio sends when it activates the platform
  // or loads a source. The setters for features these tests never touch
  // (pitch, skip silence, loop/shuffle mode, audio attributes) stay omitted.
  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async => SetShuffleModeResponse();
}
