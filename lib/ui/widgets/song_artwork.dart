import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/song_card_cache.dart';

/// Capa carregada sob demanda pelo [SongCardCache] (janela de 4× visível).
class SongArtwork extends StatefulWidget {
  const SongArtwork({
    super.key,
    required this.song,
    required this.size,
    this.radius = 12,
    this.showShadow = false,
  });

  final Song song;
  final double size;
  final double radius;
  final bool showShadow;

  @override
  State<SongArtwork> createState() => _SongArtworkState();
}

class _SongArtworkState extends State<SongArtwork> {
  SongCard? _card;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant SongArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _card = null;
      _resolve();
    }
  }

  void _resolve() {
    final cache = context.read<SongCardCache>();
    final peeked = cache.peek(widget.song.id);
    if (peeked != null) {
      _card = peeked;
      return;
    }
    cache.load(widget.song).then((card) {
      if (!mounted) return;
      if (card.song.id != widget.song.id) return;
      setState(() => _card = card);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final radius = BorderRadius.circular(widget.radius);
    final artwork = _card?.artwork;

    Widget child;
    if (artwork != null && artwork.isNotEmpty) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      child = Image.memory(
        artwork,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        cacheWidth: (size * dpr).round().clamp(64, 1080),
        errorBuilder: (context, error, stackTrace) =>
            _Placeholder(song: widget.song, size: size, radius: widget.radius),
      );
    } else {
      child = _Placeholder(
        song: widget.song,
        size: size,
        radius: widget.radius,
      );
    }

    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: widget.showShadow
              ? <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 36,
                    offset: const Offset(0, 18),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(borderRadius: radius, child: child),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.song,
    required this.size,
    required this.radius,
  });

  final Song song;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hue = (song.albumId.abs() % 360).toDouble();
    final base = HSLColor.fromAHSL(1, hue, 0.38, 0.40).toColor();
    final start = Color.lerp(base, scheme.primary, 0.35)!;
    final end = Color.lerp(base, scheme.surfaceContainerHighest, 0.55)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[start, end],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: (size * 0.38).clamp(12, 96),
          color: Colors.white.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}
