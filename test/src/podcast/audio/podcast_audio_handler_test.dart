import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:podcastshortcut/src/podcast/audio/podcast_audio_handler.dart';
import 'package:podcastshortcut/src/podcast/data/sr_api_client.dart';
import 'package:podcastshortcut/src/podcast/domain/podcast_episode.dart';
import 'package:podcastshortcut/src/podcast/domain/podcast_program.dart';

/// just_audio's AudioPlayer binds to platform channels at construction.
/// The tests install a fake platform so a real AudioPlayer object can be
/// created without native audio; the browse-tree logic never loads audio.
class _FakeJustAudioPlatform extends JustAudioPlatform {
  final players = <_FakeAudioPlayerPlatform>[];

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final player = _FakeAudioPlayerPlatform(request.id);
    players.add(player);
    return player;
  }
}

class _FakeAudioPlayerPlatform extends AudioPlayerPlatform {
  _FakeAudioPlayerPlatform(super.id);

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

PodcastProgram _program({int id = 5386, Uri? imageUrl}) => PodcastProgram(
  id: id,
  name: 'Radiokorrespondenterna Kina',
  pageUrl: Uri.parse('https://www.sverigesradio.se/show'),
  imageUrl: imageUrl,
  hasPod: true,
);

Map<String, dynamic> _episodeJson(int id, {bool playable = true}) => {
  'id': id,
  'title': 'Episode $id',
  'imageurl': 'https://example.com/ep$id.png',
  'publishdateutc': '/Date(1700000000000+0200)/',
  if (playable)
    'listenpodfile': {
      'url': 'https://podfile.cloud/audio$id.mp3',
      'duration': 600,
    },
};

(SrApiClient, int Function()) _clientServing(
  List<Map<String, dynamic>> episodes,
) {
  var calls = 0;
  final client = MockClient((request) async {
    calls++;
    return http.Response(
      jsonEncode({'episodes': episodes}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  return (SrApiClient(httpClient: client), () => calls);
}

PodcastAudioHandler _handler(
  SrApiClient client,
  List<PodcastProgram> programs,
) {
  return PodcastAudioHandler(
    apiClient: client,
    loadSubscriptions: () async => programs,
    player: AudioPlayer(handleInterruptions: false),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fakeAudioPlatform = _FakeJustAudioPlatform();
  JustAudioPlatform.instance = fakeAudioPlatform;

  group('getChildren root', () {
    test('returns one browsable item per subscription', () async {
      final (client, _) = _clientServing([]);
      final handler = _handler(client, [_program(id: 1), _program(id: 2)]);

      final children = await handler.getChildren(PodcastAudioHandler.rootId);

      expect(children.map((item) => item.id), ['show:1', 'show:2']);
      expect(children.map((item) => item.title), isNotEmpty);
      expect(children.every((item) => !item.playable!), isTrue);
      expect(
        children.every(
          (item) =>
              item.extras![AndroidContentStyle.browsableHintKey] ==
              AndroidContentStyle.gridItemHintValue,
        ),
        isTrue,
      );
    });
  });

  group('getChildren for a show', () {
    test('fetches episodes once and caches across calls', () async {
      final (client, callCount) = _clientServing([
        _episodeJson(11),
        _episodeJson(12, playable: false),
        _episodeJson(13),
      ]);
      final handler = _handler(client, [_program()]);

      final first = await handler.getChildren('show:5386');
      final second = await handler.getChildren('show:5386');

      expect(callCount(), 1);
      // The unplayable episode 12 is filtered out.
      expect(first.map((item) => item.id), ['episode:11', 'episode:13']);
      expect(second.map((item) => item.id), first.map((item) => item.id));
    });

    test('fetches only the latest API page for the car', () async {
      var calls = 0;
      final client = SrApiClient(
        httpClient: MockClient((request) async {
          calls++;
          return http.Response(
            jsonEncode({
              'episodes': [_episodeJson(11)],
              'pagination': {
                'nextpage':
                    'https://api.sr.se/v2/episodes/index?programid=5386&format=json&page=2',
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final handler = _handler(client, [_program()]);

      final children = await handler.getChildren('show:5386');

      expect(children, hasLength(1));
      expect(calls, 1);
    });

    test(
      'maps playable episode fields including art fallback and duration',
      () async {
        final (client, _) = _clientServing([_episodeJson(11)]);
        final handler = _handler(client, [
          _program(imageUrl: Uri.parse('https://example.com/show.png')),
        ]);

        final item = (await handler.getChildren('show:5386')).single;

        expect(item.id, 'episode:11');
        expect(item.title, 'Episode 11');
        expect(item.album, 'Radiokorrespondenterna Kina');
        expect(item.artist, 'Radiokorrespondenterna Kina');
        expect(item.artUri, Uri.parse('https://example.com/ep11.png'));
        expect(item.duration, const Duration(seconds: 600));
        expect(item.playable, isTrue);
        expect(
          item.extras![AndroidContentStyle.playableHintKey],
          AndroidContentStyle.listItemHintValue,
        );
        expect(handler.episodeIndex, containsPair('episode:11', isNotNull));
      },
    );

    test('unknown show id yields an empty list', () async {
      final (client, callCount) = _clientServing([_episodeJson(11)]);
      final handler = _handler(client, [_program()]);

      expect(await handler.getChildren('show:999'), isEmpty);
      expect(callCount(), 0);
      expect(await handler.getChildren('gibberish'), isEmpty);
    });

    test('an API failure yields an empty list instead of throwing', () async {
      final client = SrApiClient(
        httpClient: MockClient((request) async => http.Response('boom', 500)),
      );
      final handler = _handler(client, [_program()]);

      expect(await handler.getChildren('show:5386'), isEmpty);
    });
  });

  group('car playback entry points', () {
    test(
      'playMediaItem ignores unknown media ids without touching the player',
      () async {
        final (client, callCount) = _clientServing([_episodeJson(11)]);
        final handler = _handler(client, [_program()]);

        await handler.playMediaItem(
          const MediaItem(id: 'episode:unknown', title: 'unknown'),
        );

        expect(callCount(), 0);
      },
    );

    test(
      'playMediaItem returns while playback continues and loads one URL',
      () async {
        final (client, _) = _clientServing([
          _episodeJson(11),
          _episodeJson(12),
        ]);
        final handler = _handler(client, [_program()]);
        final item = (await handler.getChildren('show:5386')).first;

        await handler.playMediaItem(item).timeout(const Duration(seconds: 1));

        expect(handler.player.audioSources, hasLength(1));
        expect(handler.mediaItem.value?.id, 'episode:11');
        expect(handler.queue.value, hasLength(2));
        expect(handler.player.playing, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(fakeAudioPlatform.players, isNotEmpty);
        expect(
          fakeAudioPlatform.players.last.playCompleter.isCompleted,
          isFalse,
        );
        // Episode 11 is first in the queue, so there is no skipToPrevious.
        expect(handler.playbackState.value.controls, [
          MediaControl.rewind,
          MediaControl.pause,
          MediaControl.fastForward,
          MediaControl.skipToNext,
        ]);
        // The three compact slots are the 15-second jumps around play/pause.
        expect(handler.playbackState.value.androidCompactActionIndices, [
          0,
          1,
          2,
        ]);
        expect(
          handler.playbackState.value.systemActions,
          containsAll([
            MediaAction.seek,
            MediaAction.rewind,
            MediaAction.fastForward,
          ]),
        );
      },
    );

    test('playFromSearch with no matching subscription is a no-op', () async {
      final (client, callCount) = _clientServing([_episodeJson(11)]);
      final handler = _handler(client, [_program()]);

      await handler.playFromSearch('ekot');

      expect(callCount(), 0);
      expect(handler.episodeIndex, isEmpty);
    });

    test('playFromSearch matches show names case-insensitively', () async {
      final (client, callCount) = _clientServing([
        _episodeJson(11, playable: false),
        _episodeJson(12, playable: false),
      ]);
      final handler = _handler(client, [_program()]);

      // The show name matches, but it has no playable episodes, so the
      // search is a no-op that still performs the one episode fetch.
      await handler.playFromSearch('  KORRESPONDENT  ');

      expect(callCount(), 1);
      expect(handler.episodeIndex, isEmpty);
    });

    test(
      'compact indices skip episode steps when the queue has neighbours',
      () async {
        final (client, _) = _clientServing([
          _episodeJson(11),
          _episodeJson(12),
          _episodeJson(13),
        ]);
        final handler = _handler(client, [_program()]);
        final children = await handler.getChildren('show:5386');

        // Episode 12 sits in the middle, so previous and next both exist and
        // the compact slots still stay on rewind, play/pause, fast-forward.
        await handler
            .playMediaItem(children[1])
            .timeout(const Duration(seconds: 1));

        expect(handler.playbackState.value.controls, [
          MediaControl.skipToPrevious,
          MediaControl.rewind,
          MediaControl.pause,
          MediaControl.fastForward,
          MediaControl.skipToNext,
        ]);
        expect(handler.playbackState.value.androidCompactActionIndices, [
          1,
          2,
          3,
        ]);
      },
    );
  });

  group('publishQueue', () {
    test(
      'exposes the show queue, title, and current index for the car',
      () async {
        final (client, callCount) = _clientServing([]);
        final handler = _handler(client, [_program()]);
        final episode1 = PodcastEpisode(
          id: 11,
          title: 'Episode 11',
          audioUrl: Uri.parse('https://podfile.cloud/audio11.mp3'),
        );
        final episode2 = PodcastEpisode(
          id: 12,
          title: 'Episode 12',
          audioUrl: Uri.parse('https://podfile.cloud/audio12.mp3'),
        );

        await handler.publishQueue(
          episode: episode2,
          program: _program(),
          episodes: [episode1, episode2],
        );

        expect(handler.queue.value.map((item) => item.id), [
          'episode:11',
          'episode:12',
        ]);
        expect(handler.queueTitle.value, 'Radiokorrespondenterna Kina');
        expect(handler.playbackState.value.queueIndex, 1);
        expect(handler.mediaItem.value?.id, 'episode:12');
        expect(handler.mediaItem.value?.album, 'Radiokorrespondenterna Kina');
        // Publishing the queue must not fetch anything; the phone already has
        // the episode list from the screen.
        expect(callCount(), 0);
      },
    );

    test('an unknown episode leaves the queue untouched', () async {
      final (client, callCount) = _clientServing([]);
      final handler = _handler(client, [_program()]);
      final episode1 = PodcastEpisode(
        id: 11,
        title: 'Episode 11',
        audioUrl: Uri.parse('https://podfile.cloud/audio11.mp3'),
      );
      final stranger = PodcastEpisode(
        id: 99,
        title: 'Episode 99',
        audioUrl: Uri.parse('https://podfile.cloud/audio99.mp3'),
      );

      await handler.publishQueue(
        episode: stranger,
        program: _program(),
        episodes: [episode1],
      );

      expect(handler.queue.value, isEmpty);
      expect(handler.mediaItem.value, isNull);
      expect(handler.episodeIndex, isEmpty);
      expect(callCount(), 0);
    });
  });

  group('rewind and fast-forward', () {
    // The overridden handler jumps read the just_audio player state, so the
    // tests set the player position through the player itself. They need no
    // AudioService.config and never depend on the MediaItem duration, which
    // phone-started playback does not set at all.
    test(
      'fastForward seeks 15 seconds ahead of the current position',
      () async {
        final handler = _handler(_clientServing([]).$1, [_program()]);
        await handler.player.seek(const Duration(seconds: 100));

        await handler.fastForward();

        expect(handler.player.position, const Duration(seconds: 115));
      },
    );

    test('rewind seeks 15 seconds behind the current position', () async {
      final handler = _handler(_clientServing([]).$1, [_program()]);
      await handler.player.seek(const Duration(seconds: 100));

      await handler.rewind();

      expect(handler.player.position, const Duration(seconds: 85));
    });

    test('rewind clamps at the start of the episode', () async {
      final handler = _handler(_clientServing([]).$1, [_program()]);
      await handler.player.seek(const Duration(seconds: 5));

      await handler.rewind();

      expect(handler.player.position, Duration.zero);
    });

    test(
      'fastForward still moves forward 15 seconds without a MediaItem duration',
      () async {
        final handler = _handler(_clientServing([]).$1, [_program()]);
        // Phone-started playback publishes a MediaItem without a duration;
        // the jump must not clamp to Duration.zero like the stock
        // SeekHandler does.
        handler.mediaItem.add(
          const MediaItem(id: 'episode:11', title: 'Episode 11'),
        );
        await handler.player.seek(const Duration(seconds: 100));

        await handler.fastForward();

        expect(handler.player.position, const Duration(seconds: 115));
      },
    );

    test('fastForward clamps at the player duration', () async {
      final handler = _handler(_clientServing([]).$1, [_program()]);
      handler.mediaItem.add(
        const MediaItem(id: 'episode:11', title: 'Episode 11'),
      );
      // The fake just_audio platform reports a 10-minute load, so the player
      // knows the duration even though the MediaItem does not.
      await handler.player.setAudioSource(
        AudioSource.uri(Uri.parse('https://podfile.cloud/audio11.mp3')),
      );
      await handler.player.seek(
        const Duration(minutes: 10) - const Duration(seconds: 5),
      );

      await handler.fastForward();

      expect(handler.player.position, const Duration(minutes: 10));
    });
  });
}
