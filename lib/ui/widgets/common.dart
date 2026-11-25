import 'package:flutter/material.dart';

import '../../data/models.dart';
import 'song_artwork.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleLarge),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 20 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: compact ? 60 : 82,
              height: compact ? 60 : 82,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(compact ? 20 : 26),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Icon(
                icon,
                size: compact ? 28 : 38,
                color: scheme.primary,
              ),
            ),
            SizedBox(height: compact ? 14 : 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class GradientIconCover extends StatelessWidget {
  const GradientIconCover({
    super.key,
    required this.icon,
    required this.color,
    required this.size,
    this.radius = 20,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            color.withValues(alpha: 0.92),
            Color.lerp(color, scheme.surface, 0.55)!,
          ],
        ),
      ),
      child: Icon(
        icon,
        size: size * 0.42,
        color: Colors.white.withValues(alpha: 0.95),
      ),
    );
  }
}

class CollectionCover extends StatelessWidget {
  const CollectionCover({
    super.key,
    required this.songs,
    required this.size,
    this.radius = 18,
    this.icon = Icons.queue_music_rounded,
    this.color,
  });

  final List<Song> songs;
  final double size;
  final double radius;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (songs.isEmpty) {
      return GradientIconCover(
        icon: icon,
        color: color ?? scheme.primary,
        size: size,
        radius: radius,
      );
    }
    final visible = songs.take(4).toList();
    final cell = size / 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: Column(
          children: <Widget>[
            for (var row = 0; row < 2; row++)
              SizedBox(
                height: cell,
                child: Row(
                  children: <Widget>[
                    for (var column = 0; column < 2; column++)
                      SizedBox(
                        width: cell,
                        child: _cell(
                          row * 2 + column < visible.length
                              ? visible[row * 2 + column]
                              : null,
                          cell,
                          scheme,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(Song? song, double cell, ColorScheme scheme) {
    if (song == null) {
      return ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Icon(
          Icons.music_note_rounded,
          size: cell * 0.35,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      );
    }
    return SongArtwork(song: song, size: cell, radius: 0);
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                value,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
