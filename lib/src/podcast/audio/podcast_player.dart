import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'podcast_audio_handler.dart';

/// Player operations needed by the podcast UI, abstracted so tests can
/// provide a fake implementation without native audio or network access.
abstract interface class PodcastPlayer {
  bool get playing;
  Stream<bool> get playingStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;

  /// Loads [audioUrl] and makes it ready to play.
  Future<void> setUrlAndPlay(
    Uri audioUrl, {
    required String id,
    required String album,
    required String title,
    String? artist,
    Uri? artUri,
  });

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

/// The production [PodcastPlayer]. Drives the [AudioPlayer] owned by the
/// shared [PodcastAudioHandler], so the phone UI, the media notification,
/// and later Android Auto all follow one playback state.
class AudioServicePodcastPlayer implements PodcastPlayer {
  AudioServicePodcastPlayer(this._handler);

  final PodcastAudioHandler _handler;

  AudioPlayer get _player => _handler.player;

  @override
  bool get playing => _player.playing;

  @override
  Stream<bool> get playingStream =>
      _player.playerStateStream.map((state) => state.playing);

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Future<void> setUrlAndPlay(
    Uri audioUrl, {
    required String id,
    required String album,
    required String title,
    String? artist,
    Uri? artUri,
  }) async {
    await _player.setAudioSource(AudioSource.uri(audioUrl));
    _handler.mediaItem.add(
      MediaItem(
        id: id,
        album: album,
        title: title,
        artist: artist,
        artUri: artUri,
      ),
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _player.dispose();
}
