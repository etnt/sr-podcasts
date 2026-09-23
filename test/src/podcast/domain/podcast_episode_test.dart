import 'package:flutter_test/flutter_test.dart';
import 'package:podcastshortcut/src/podcast/domain/podcast_episode.dart';

void main() {
  group('PodcastEpisode.fromJson', () {
    final validEpisode = <String, dynamic>{
      'id': 2877969,
      'title': 'Därför platsar BRICS i Kinas världsordning',
      'description': 'Med BRICS-samarbetet som verktyg.',
      'url': 'https://www.sverigesradio.se/avsnitt/2877969',
      'publishdateutc': '/Date(1790008380000)/',
      'imageurl': 'https://static-cdn.sr.se/images/5386/image.jpg',
      'listenpodfile': {
        'duration': 1620,
        'url': 'https://static-cdn.sr.se/audio/episode.mp3',
      },
    };

    test('parses episode metadata, audio, duration, and SR date', () {
      final episode = PodcastEpisode.fromJson(validEpisode);

      expect(episode.id, 2877969);
      expect(episode.title, 'Därför platsar BRICS i Kinas världsordning');
      expect(episode.description, 'Med BRICS-samarbetet som verktyg.');
      expect(
        episode.audioUrl?.toString(),
        'https://static-cdn.sr.se/audio/episode.mp3',
      );
      expect(episode.duration, const Duration(seconds: 1620));
      expect(
        episode.publishedAt?.toUtc().millisecondsSinceEpoch,
        1790008380000,
      );
      expect(episode.isPlayable, isTrue);
    });

    test('keeps optional fields absent without making parsing fail', () {
      final episode = PodcastEpisode.fromJson({'id': 2, 'title': 'Episode'});

      expect(episode.description, isNull);
      expect(episode.pageUrl, isNull);
      expect(episode.imageUrl, isNull);
      expect(episode.publishedAt, isNull);
      expect(episode.duration, isNull);
      expect(episode.isPlayable, isFalse);
    });

    test('rejects missing or non-HTTPS audio urls as unplayable', () {
      final missingAudio = PodcastEpisode.fromJson({
        ...validEpisode,
        'listenpodfile': null,
      });
      final nonHttpsAudio = PodcastEpisode.fromJson({
        ...validEpisode,
        'listenpodfile': {'url': 'http://example.com/audio.mp3'},
      });

      expect(missingAudio.isPlayable, isFalse);
      expect(nonHttpsAudio.isPlayable, isFalse);
    });

    test('throws a format exception when required fields are invalid', () {
      expect(
        () => PodcastEpisode.fromJson({'id': 1}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
