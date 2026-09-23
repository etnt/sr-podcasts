import 'package:flutter/material.dart';

import '../../domain/podcast_program.dart';

/// Round show artwork with a themed placeholder for missing or broken images.
class ProgramArtwork extends StatelessWidget {
  const ProgramArtwork({super.key, required this.program, this.size = 56});

  final PodcastProgram program;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: program.imageUrl == null
            ? const _Placeholder()
            : Image.network(
                program.imageUrl.toString(),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _Placeholder(),
              ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Icon(
      Icons.podcasts,
      color: Theme.of(context).colorScheme.onSecondaryContainer,
    ),
  );
}
