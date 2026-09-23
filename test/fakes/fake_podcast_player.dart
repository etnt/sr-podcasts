import 'dart:async';

import 'package:podcastshortcut/src/podcast/audio/podcast_player.dart';

/// A broadcast stream that always replays its latest value to new listeners
/// and never drops events emitted while no one is listening yet.
class _ValueStream<T> extends Stream<T> {
  _ValueStream(this._initialValue) : _value = _initialValue;

  final T _initialValue;
  T _value;
  final StreamController<T> _controller = StreamController<T>.broadcast();

  void add(T value) {
    _value = value;
    if (_controller.hasListener) _controller.add(value);
  }

  void reset() {
    _value = _initialValue;
    if (_controller.hasListener) _controller.add(_value);
  }

  Future<void> close() => _controller.close();

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final subscription = _controller.stream.listen(
      (event) {
        _value = event;
        onData?.call(event);
      },
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    final initial = _value;
    if (onData != null) {
      scheduleMicrotask(() => onData(initial));
    }
    return subscription;
  }
}

/// In-memory [PodcastPlayer] for widget and integration tests. No native
/// audio and no network access; state changes only when a test asks for them.
class FakePodcastPlayer implements PodcastPlayer {
  FakePodcastPlayer({
    this.initialDuration = const Duration(minutes: 27, seconds: 3),
  });

  final Duration? initialDuration;
  final List<Uri> loadedUrls = [];
  final List<Duration> seekPositions = [];
  int playCalls = 0;
  int pauseCalls = 0;
  bool failOnLoad = false;

  @override
  bool playing = false;

  late final _playing = _ValueStream<bool>(false);
  late final _position = _ValueStream<Duration>(Duration.zero);
  late final _duration = _ValueStream<Duration?>(initialDuration);

  @override
  Stream<bool> get playingStream => _playing;

  @override
  Stream<Duration> get positionStream => _position;

  @override
  Stream<Duration?> get durationStream => _duration;

  void emitPlaying(bool value) {
    playing = value;
    _playing.add(value);
  }

  void emitPosition(Duration value) => _position.add(value);

  void emitDuration(Duration? value) => _duration.add(value);

  @override
  Future<void> setUrlAndPlay(
    Uri audioUrl, {
    required String id,
    required String album,
    required String title,
    String? artist,
    Uri? artUri,
  }) async {
    loadedUrls.add(audioUrl);
    if (failOnLoad) {
      failOnLoad = false;
      throw const FormatException('simulated load failure');
    }
    playing = true;
    emitPlaying(true);
  }

  @override
  Future<void> play() async {
    playCalls++;
    playing = true;
    emitPlaying(true);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    playing = false;
    emitPlaying(false);
  }

  @override
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
    emitPosition(position);
  }

  @override
  Future<void> dispose() async {
    await _playing.close();
    await _position.close();
    await _duration.close();
  }
}
