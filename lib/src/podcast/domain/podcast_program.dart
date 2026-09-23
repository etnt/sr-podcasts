class PodcastProgram {
  const PodcastProgram({
    required this.id,
    required this.name,
    required this.pageUrl,
    this.imageUrl,
    this.description,
    this.hasPod = false,
  });

  final int id;
  final String name;
  final Uri pageUrl;
  final Uri? imageUrl;
  final String? description;
  final bool hasPod;

  factory PodcastProgram.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final pageUrl = _httpsUri(json['programurl']);
    if (id is! num ||
        name is! String ||
        name.trim().isEmpty ||
        pageUrl == null) {
      throw const FormatException('Program entry is missing id, name, or URL.');
    }
    return PodcastProgram(
      id: id.toInt(),
      name: name.trim(),
      pageUrl: pageUrl,
      imageUrl: _httpsUri(json['programimage']),
      description: _optionalText(json['description']),
      hasPod: json['haspod'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'programurl': pageUrl.toString(),
    if (imageUrl != null) 'programimage': imageUrl.toString(),
    if (description != null) 'description': description,
    'haspod': hasPod,
  };

  @override
  bool operator ==(Object other) => other is PodcastProgram && other.id == id;

  @override
  int get hashCode => id.hashCode;

  static String? _optionalText(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Uri? _httpsUri(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return uri;
  }
}
