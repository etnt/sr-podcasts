import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/podcast_player.dart';
import '../../audio/podcast_playback.dart';

class EpisodePlayerControls extends ConsumerWidget {
  const EpisodePlayerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final episode = playback.episode;
    if (episode == null) return const SizedBox.shrink();

    final player = ref.watch(podcastPlayerProvider);
    final isPlaying = ref.watch(_playingProvider(player)).value ?? false;
    final position =
        ref.watch(_positionProvider(player)).value ?? Duration.zero;
    final duration =
        ref.watch(_durationProvider(player)).value ?? episode.duration;
    final showProgress = duration != null && duration.inMilliseconds > 0;
    final clampedPosition = showProgress && position > duration
        ? duration
        : position;

    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                episode.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (playback.errorMessage case final message?) ...[
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: playback.isLoading
                        ? 'Loading episode'
                        : isPlaying
                        ? 'Pause'
                        : 'Play',
                    onPressed: playback.isLoading
                        ? null
                        : () {
                            if (playback.errorMessage != null) {
                              ref.read(playbackProvider.notifier).retry();
                            } else {
                              ref
                                  .read(playbackProvider.notifier)
                                  .togglePlayback();
                            }
                          },
                    icon: playback.isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  ),
                  Expanded(
                    child: Slider(
                      min: 0,
                      max: showProgress
                          ? duration.inMilliseconds.toDouble()
                          : 1,
                      value: showProgress
                          ? clampedPosition.inMilliseconds.toDouble()
                          : 0,
                      onChanged: showProgress
                          ? (value) => ref
                                .read(playbackProvider.notifier)
                                .seek(Duration(milliseconds: value.round()))
                          : null,
                    ),
                  ),
                  Text(
                    showProgress ? _formatDuration(duration) : '--:--',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              if (showProgress)
                Padding(
                  padding: const EdgeInsets.only(left: 56, right: 44, top: 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _formatDuration(clampedPosition),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (minutes >= 60) {
      final hours = duration.inHours;
      final remainingMinutes = minutes.remainder(60).toString().padLeft(2, '0');
      return '$hours:$remainingMinutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

final _playingProvider = StreamProvider.autoDispose.family<bool, PodcastPlayer>(
  (ref, player) => player.playingStream,
);
final _positionProvider = StreamProvider.autoDispose
    .family<Duration, PodcastPlayer>((ref, player) => player.positionStream);
final _durationProvider = StreamProvider.autoDispose
    .family<Duration?, PodcastPlayer>((ref, player) => player.durationStream);
