import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/playlist_controller.dart';
import '../../state/player_controller.dart';
import '../sheets/song_sheets.dart';
import 'song_artwork.dart';

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.playlistId,
    this.queue,
    this.queueLabel,
    this.showArtwork = true,
    this.showFavorite = true,
    this.dense = false,
    this.enableLongPress = true,
    this.selecting = false,
    this.selected = false,
    this.onSelectionTap,
    this.onSelectionLongPress,
  });

  final Song song;
  final VoidCallback onTap;
  final String? playlistId;
  final List<Song>? queue;
  final String? queueLabel;
  final bool showArtwork;
  final bool showFavorite;
  final bool dense;
  final bool enableLongPress;
  final bool selecting;
  final bool selected;
  final VoidCallback? onSelectionTap;
  final VoidCallback? onSelectionLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isFavorite = context.select<PlaylistController, bool>(
      (controller) => controller.isFavorite(song.id),
    );
    final isCurrent = context.select<PlayerController, bool>(
      (controller) => controller.currentSong?.id == song.id,
    );
    final isPlaying = context.select<PlayerController, bool>(
      (controller) => controller.isPlaying,
    );

    final artworkSize = dense ? 40.0 : 52.0;

    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.16)
          : isCurrent
              ? scheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
      child: InkWell(
        onTap: selecting ? onSelectionTap : onTap,
        onLongPress: onSelectionLongPress ??
            (enableLongPress ? () => _openActions(context) : null),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            14,
            dense ? 5 : 7,
            6,
            dense ? 5 : 7,
          ),
          child: Row(
            children: <Widget>[
              if (showArtwork) ...<Widget>[
                SongArtwork(
                  song: song,
                  size: artworkSize,
                  radius: dense ? 9 : 12,
                ),
                SizedBox(width: dense ? 10 : 12),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        if (isCurrent) ...<Widget>[
                          Icon(
                            isPlaying
                                ? Icons.graphic_eq_rounded
                                : Icons.pause_rounded,
                            size: 14,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: (dense
                                    ? theme.textTheme.bodyMedium
                                    : theme.textTheme.titleSmall)
                                ?.copyWith(
                              color: isCurrent
                                  ? scheme.primary
                                  : scheme.onSurface,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        if (song.isLossless) ...<Widget>[
                          _FormatBadge(label: song.format),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            song.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!dense)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    song.durationLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (selecting)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _SelectionCheck(selected: selected),
                )
              else ...<Widget>[
                if (showFavorite)
                  _IconAction(
                    icon: isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color:
                        isFavorite ? scheme.primary : scheme.onSurfaceVariant,
                    tooltip:
                        isFavorite ? 'Remover dos favoritos' : 'Favoritar',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      context.read<PlaylistController>().toggleFavorite(song);
                    },
                  ),
                _IconAction(
                  icon: Icons.more_vert_rounded,
                  color: scheme.onSurfaceVariant,
                  tooltip: 'Mais opções',
                  onPressed: () => _openActions(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openActions(BuildContext context) {
    showSongActions(
      context,
      song,
      playlistId: playlistId,
      queue: queue,
      queueLabel: queueLabel,
    );
  }
}

class SongGridCard extends StatelessWidget {
  const SongGridCard({
    super.key,
    required this.song,
    required this.onTap,
    this.playlistId,
    this.queue,
    this.queueLabel,
    this.selecting = false,
    this.selected = false,
    this.onSelectionTap,
    this.onSelectionLongPress,
  });

  final Song song;
  final VoidCallback onTap;
  final String? playlistId;
  final List<Song>? queue;
  final String? queueLabel;
  final bool selecting;
  final bool selected;
  final VoidCallback? onSelectionTap;
  final VoidCallback? onSelectionLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isFavorite = context.select<PlaylistController, bool>(
      (controller) => controller.isFavorite(song.id),
    );
    final isCurrent = context.select<PlayerController, bool>(
      (controller) => controller.currentSong?.id == song.id,
    );
    final isPlaying = context.select<PlayerController, bool>(
      (controller) => controller.isPlaying,
    );

    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.18)
          : isCurrent
              ? scheme.primary.withValues(alpha: 0.10)
              : (theme.brightness == Brightness.dark
                  ? scheme.surfaceContainerLow
                  : Colors.white),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: selecting ? onSelectionTap : onTap,
        onLongPress: onSelectionLongPress ??
            () => showSongActions(
                  context,
                  song,
                  playlistId: playlistId,
                  queue: queue,
                  queueLabel: queueLabel,
                ),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : isCurrent
                      ? scheme.primary.withValues(alpha: 0.5)
                      : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: <Widget>[
                            SongArtwork(
                              song: song,
                              size: constraints.maxWidth,
                              radius: 14,
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: selecting
                                  ? _SelectionCheck(selected: selected)
                                  : _OverlayIcon(
                                      icon: isFavorite
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: isFavorite
                                          ? scheme.primary
                                          : Colors.white,
                                      onPressed: () {
                                        HapticFeedback.selectionClick();
                                        context
                                            .read<PlaylistController>()
                                            .toggleFavorite(song);
                                      },
                                    ),
                            ),
                            if (isCurrent)
                              Positioned(
                                left: 4,
                                bottom: 4,
                                child: _OverlayIcon(
                                  icon: isPlaying
                                      ? Icons.graphic_eq_rounded
                                      : Icons.pause_rounded,
                                  color: scheme.primary,
                                  onPressed: null,
                                ),
                              ),
                            if (song.isLossless)
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: _FormatBadge(label: song.format),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isCurrent ? scheme.primary : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${song.durationLabel} • ${song.format}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CompactSongTile extends StatelessWidget {
  const CompactSongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.playlistId,
    this.queue,
    this.queueLabel,
    this.selecting = false,
    this.selected = false,
    this.onSelectionTap,
    this.onSelectionLongPress,
  });

  final Song song;
  final VoidCallback onTap;
  final String? playlistId;
  final List<Song>? queue;
  final String? queueLabel;
  final bool selecting;
  final bool selected;
  final VoidCallback? onSelectionTap;
  final VoidCallback? onSelectionLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isCurrent = context.select<PlayerController, bool>(
      (controller) => controller.currentSong?.id == song.id,
    );
    return Material(
      color: selected ? scheme.primary.withValues(alpha: 0.14) : Colors.transparent,
      child: InkWell(
        onTap: selecting ? onSelectionTap : onTap,
        onLongPress: onSelectionLongPress ??
            () => showSongActions(
                  context,
                  song,
                  playlistId: playlistId,
                  queue: queue,
                  queueLabel: queueLabel,
                ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Row(
            children: <Widget>[
              if (selecting)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _SelectionCheck(selected: selected, size: 18),
                )
              else
                Icon(
                  isCurrent
                      ? Icons.graphic_eq_rounded
                      : Icons.music_note_rounded,
                  size: 15,
                  color: isCurrent ? scheme.primary : scheme.onSurfaceVariant,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isCurrent ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                song.durationLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (!selecting)
                _IconAction(
                  icon: Icons.more_vert_rounded,
                  color: scheme.onSurfaceVariant,
                  tooltip: 'Mais opções',
                  onPressed: () => showSongActions(
                    context,
                    song,
                    playlistId: playlistId,
                    queue: queue,
                    queueLabel: queueLabel,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      color: color,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

class _OverlayIcon extends StatelessWidget {
  const _OverlayIcon({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _SelectionCheck extends StatelessWidget {
  const _SelectionCheck({required this.selected, this.size = 22});

  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? scheme.primary : Colors.transparent,
        border: Border.all(
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
          width: 2,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: size * 0.72, color: scheme.onPrimary)
          : null,
    );
  }
}

class _FormatBadge extends StatelessWidget {
  const _FormatBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}
