class PodcastProgram {
  const PodcastProgram({
    required this.id,
    required this.name,
    required this.pageUrl,
    this.imageUrl,
  });

  final int id;
  final String name;
  final Uri pageUrl;
  final Uri? imageUrl;
}
