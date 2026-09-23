class PodcastEpisode {
  const PodcastEpisode({
    required this.id,
    required this.title,
    required this.audioUrl,
    this.description,
    this.pageUrl,
    this.imageUrl,
    this.publishedAt,
    this.duration,
  });

  final int id;
  final String title;
  final String? description;
  final Uri? pageUrl;
  final Uri? imageUrl;
  final DateTime? publishedAt;
  final Uri? audioUrl;
  final Duration? duration;

  bool get isPlayable => audioUrl != null;

  factory PodcastEpisode.fromJson(Map<String, dynamic> json) {
    final listenFile = json['listenpodfile'];
    final listenFileMap = listenFile is Map<String, dynamic>
        ? listenFile
        : null;
    final audioUrl = _httpsUri(listenFileMap?['url']);
    final durationSeconds = listenFileMap?['duration'];

    return PodcastEpisode(
      id: _requiredInt(json['id'], 'id'),
      title: _requiredString(json['title'], 'title'),
      description: _optionalString(json['description']),
      pageUrl: _httpsUri(json['url']),
      imageUrl: _httpsUri(json['imageurl']),
      publishedAt: _parseSrDate(json['publishdateutc']),
      audioUrl: audioUrl,
      duration: durationSeconds is num && durationSeconds > 0
          ? Duration(seconds: durationSeconds.toInt())
          : null,
    );
  }

  static int _requiredInt(Object? value, String field) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw FormatException('Episode field "$field" must be an integer.');
  }

  static String _requiredString(Object? value, String field) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    throw FormatException('Episode field "$field" must be a non-empty string.');
  }

  static String? _optionalString(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static Uri? _httpsUri(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return uri;
  }

  static DateTime? _parseSrDate(Object? value) {
    if (value is! String) return null;
    final match = RegExp(r'^/Date\((-?\d+)(?:[+-]\d+)?\)/$').firstMatch(value);
    if (match == null) return null;
    final millis = int.tryParse(match.group(1)!);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
  }
}
