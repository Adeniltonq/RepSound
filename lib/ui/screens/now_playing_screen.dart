import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../core/utils.dart';
import '../../data/models.dart';
import '../../data/playlist_controller.dart';
import '../../state/player_controller.dart';
import '../sheets/lyrics_sheet.dart';
import '../sheets/song_sheets.dart';
import '../widgets/common.dart';
import '../widgets/song_artwork.dart';
import 'equalizer_screen.dart';
import 'listening_stats_screen.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  double? _dragMs;
  double _swipeX = 0;

  void _endSwipe(DragEndDetails details, PlayerController player) {
    final velocity = details.primaryVelocity ?? 0;
    if (_swipeX.abs() > 90 || velocity.abs() > 500) {
      HapticFeedback.mediumImpact();
      if (_swipeX < 0 || velocity < 0) {
        player.next();
      } else {
        player.previous();
      }
    }
    setState(() => _swipeX = 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final player = context.watch<PlayerController>();
    final profile = context.watch<PlaylistController>();
    final song = player.currentSong;

    if (song == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.music_note_rounded,
          title: 'Nada tocando',
          message: 'Escolha uma faixa na biblioteca para começar.',
        ),
      );
    }

    final isFavorite = profile.isFavorite(song.id);
    final background = theme.scaffoldBackgroundColor;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.30),
                background,
              ),
              Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.10),
                background,
              ),
              background,
            ],
            stops: const <double>[0, 0.38, 0.72],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _TopBar(player: player),
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final available = math.min(
                        constraints.maxWidth - 64,
                        constraints.maxHeight - 12,
                      );
                      final size =
                          available.clamp(120.0, 360.0).toDouble();
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            _swipeX = (_swipeX + details.delta.dx)
                                .clamp(-140.0, 140.0);
                          });
                        },
                        onHorizontalDragEnd: (details) =>
                            _endSwipe(details, player),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          transform: Matrix4.translationValues(_swipeX, 0, 0)
                            ..rotateZ(_swipeX / 2200),
                          child: Hero(
                            tag: 'np-art',
                            child: SongArtwork(
                              song: song,
                              size: size,
                              radius: 28,
                              showShadow: true,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 16, 0),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            song.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${song.artist} • ${song.album}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: isFavorite
                          ? 'Remover dos favoritos'
                          : 'Favoritar',
                      onPressed: () => profile.toggleFavorite(song),
                      icon: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFavorite
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              _SeekBar(
                player: player,
                song: song,
                dragMs: _dragMs,
                onDrag: (value) => setState(() => _dragMs = value),
                onDragEnd: (value) {
                  setState(() => _dragMs = null);
                  player.seek(Duration(milliseconds: value.round()));
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    IconButton(
                      tooltip: player.isShuffling
                          ? 'Desativar aleatório'
                          : 'Aleatório',
                      onPressed: player.toggleShuffle,
                      icon: const Icon(Icons.shuffle_rounded),
                      color: player.isShuffling
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    IconButton(
                      tooltip: 'Anterior',
                      onPressed: player.previous,
                      icon: const Icon(Icons.skip_previous_rounded),
                      iconSize: 38,
                    ),
                    _PlayButton(player: player),
                    IconButton(
                      tooltip: 'Próxima',
                      onPressed: player.next,
                      icon: const Icon(Icons.skip_next_rounded),
                      iconSize: 38,
                    ),
                    IconButton(
                      tooltip: player.repeatLabel,
                      onPressed: player.cycleRepeatMode,
                      icon: Icon(
                        player.loopMode == LoopMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                      ),
                      color: player.loopMode == LoopMode.off
                          ? scheme.onSurfaceVariant
                          : scheme.primary,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _BottomAction(
                      icon: Icons.bedtime_outlined,
                      label: _timerLabel(player),
                      active: player.sleepRemaining != null ||
                          player.sleepAtTrackEnd,
                      onTap: () => showSleepTimerSheet(context),
                    ),
                    _BottomAction(
                      icon: Icons.queue_music_rounded,
                      label: 'Fila',
                      onTap: () => showQueueSheet(context),
                    ),
                    _BottomAction(
                      icon: Icons.lyrics_outlined,
                      label: 'Letras',
                      onTap: () => showLyricsSheet(context, song),
                    ),
                    _BottomAction(
                      icon: Icons.equalizer_rounded,
                      label: 'Equalizador',
                      active: player.eqEnabled,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const EqualizerScreen(),
                        ),
                      ),
                    ),
                    _BottomAction(
                      icon: Icons.info_outline_rounded,
                      label: 'Detalhes',
                      onTap: () => showSongInfoSheet(context, song),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _timerLabel(PlayerController player) {
    final remaining = player.sleepRemaining;
    if (remaining == null) {
      return player.sleepAtTrackEnd ? 'Fim da faixa' : 'Timer';
    }
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Fechar',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.expand_more_rounded, size: 30),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  player.contextLabel.isEmpty
                      ? 'Reproduzindo'
                      : player.contextLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Fila • ${player.queue.length} faixas',
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
            tooltip: 'Estatísticas de escuta',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ListeningStatsScreen(),
              ),
            ),
            icon: const Icon(Icons.insights_rounded),
          ),
          IconButton(
            tooltip: 'Fila de reprodução',
            onPressed: () => showQueueSheet(context),
            icon: const Icon(Icons.queue_music_rounded),
          ),
        ],
      ),
    );
  }
}

class _SeekBar extends StatelessWidget {
  const _SeekBar({
    required this.player,
    required this.song,
    required this.dragMs,
    required this.onDrag,
    required this.onDragEnd,
  });

  final PlayerController player;
  final Song song;
  final double? dragMs;
  final ValueChanged<double> onDrag;
  final ValueChanged<double> onDragEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = player.player.duration ??
            Duration(milliseconds: song.durationMs);
        final maxMs = duration.inMilliseconds > 0
            ? duration.inMilliseconds.toDouble()
            : 1.0;
        final current =
            (dragMs ?? position.inMilliseconds.toDouble()).clamp(0.0, maxMs);
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Slider(
                min: 0,
                max: maxMs,
                value: current,
                onChanged: onDrag,
                onChangeEnd: onDragEnd,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                children: <Widget>[
                  Text(
                    formatDuration(current.round()),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatDuration(duration.inMilliseconds),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.42),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: scheme.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: player.togglePlayPause,
          child: SizedBox(
            width: 68,
            height: 68,
            child: Icon(
              player.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              size: 38,
              color: scheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = active ? scheme.primary : scheme.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
