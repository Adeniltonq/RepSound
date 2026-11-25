import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/player_controller.dart';
import '../navigation.dart';
import 'song_artwork.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final player = context.watch<PlayerController>();
    final song = player.currentSong;
    if (song == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Material(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF121722)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openNowPlaying(context),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.20),
              ),
              gradient: LinearGradient(
                colors: <Color>[
                  scheme.primary.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _MiniProgress(player: player),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                  child: Row(
                    children: <Widget>[
                      Hero(
                        tag: 'np-art',
                        child: SongArtwork(
                          song: song,
                          size: 44,
                          radius: 11,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: player.previous,
                        tooltip: 'Anterior',
                        icon: const Icon(Icons.skip_previous_rounded, size: 26),
                        color: scheme.onSurface,
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        onPressed: player.togglePlayPause,
                        tooltip: player.isPlaying ? 'Pausar' : 'Reproduzir',
                        icon: Icon(
                          player.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 28,
                        ),
                        color: scheme.primary,
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        onPressed: player.next,
                        tooltip: 'Próxima',
                        icon: const Icon(Icons.skip_next_rounded, size: 26),
                        color: scheme.onSurface,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  const _MiniProgress({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = player.player.duration ?? Duration.zero;
        final value = duration.inMilliseconds > 0
            ? (position.inMilliseconds / duration.inMilliseconds)
                .clamp(0.0, 1.0)
            : 0.0;
        return LinearProgressIndicator(
          value: value,
          minHeight: 2,
          backgroundColor: scheme.outlineVariant.withValues(alpha: 0.4),
          color: scheme.primary,
        );
      },
    );
  }
}
