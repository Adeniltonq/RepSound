import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../core/utils.dart';
import '../../data/models.dart';
import '../../data/playlist_controller.dart';
import '../../state/player_controller.dart';
import '../../state/settings_controller.dart';
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
  String? _seekFlash;
  bool _seekFlashForward = true;
  int _seekFlashToken = 0;

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

  /// Avança/retrocede sem sair da faixa. Mostra um aviso curto na capa.
  void _seekBy(PlayerController player, int seconds) {
    final durationMs = player.player.duration?.inMilliseconds ??
        player.currentSong?.durationMs ??
        0;
    if (durationMs <= 0) return;
    final target = seekTargetMs(
      player.player.position.inMilliseconds,
      seconds,
      durationMs,
    );
    if (target == player.player.position.inMilliseconds) return;
    player.seek(Duration(milliseconds: target));
    HapticFeedback.selectionClick();
    _showSeekFlash(seconds > 0, seconds.abs());
  }

  void _showSeekFlash(bool forward, int seconds) {
    final token = ++_seekFlashToken;
    setState(() {
      _seekFlash = '${forward ? '+' : '−'}$seconds s';
      _seekFlashForward = forward;
    });
    Future<void>.delayed(const Duration(milliseconds: 750), () {
      if (!mounted || token != _seekFlashToken) return;
      setState(() => _seekFlash = null);
    });
  }

  void _handleArtworkTap(
    TapUpDetails details,
    double size,
    PlayerController player,
  ) {
    final step = context.read<SettingsController>().seekStepSeconds;
    final action = seekTapAction(details.localPosition.dx, size);
    if (action == SeekTapAction.rewind) {
      _seekBy(player, -step);
    } else if (action == SeekTapAction.forward) {
      _seekBy(player, step);
    } else {
      player.togglePlayPause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final player = context.watch<PlayerController>();
    final profile = context.watch<PlaylistController>();
    final settings = context.watch<SettingsController>();
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
    final media = MediaQuery.sizeOf(context);
    final compact = media.height < 700 || media.width < 380;

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
              _TopBar(player: player, compact: compact),
              Expanded(
                child: _Artwork(
                  song: song,
                  player: player,
                  compact: compact,
                  swipeX: _swipeX,
                  flash: _seekFlash,
                  flashForward: _seekFlashForward,
                  onDragUpdate: (dx) {
                    setState(() {
                      _swipeX = (_swipeX + dx).clamp(-140.0, 140.0);
                    });
                  },
                  onDragEnd: (details) => _endSwipe(details, player),
                  onTap: settings.tapToSeek
                      ? (details, size) =>
                          _handleArtworkTap(details, size, player)
                      : null,
                ),
              ),
              Padding(
                padding: compact
                    ? const EdgeInsets.fromLTRB(16, 8, 6, 0)
                    : const EdgeInsets.fromLTRB(24, 18, 16, 0),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            song.title,
                            maxLines: compact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: (compact
                                    ? theme.textTheme.titleLarge
                                    : theme.textTheme.headlineSmall)
                                ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                          SizedBox(height: compact ? 1 : 4),
                          Text(
                            '${song.artist} • ${song.album}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: (compact
                                    ? theme.textTheme.bodySmall
                                    : theme.textTheme.bodyMedium)
                                ?.copyWith(
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
                      visualDensity: compact ? VisualDensity.compact : null,
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
              if (!compact) const SizedBox(height: 4),
              _SeekBar(
                player: player,
                song: song,
                compact: compact,
                dragMs: _dragMs,
                onDrag: (value) => setState(() => _dragMs = value),
                onDragEnd: (value) {
                  setState(() => _dragMs = null);
                  player.seek(Duration(milliseconds: value.round()));
                },
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    IconButton(
                      tooltip: player.isShuffling
                          ? 'Desativar aleatório'
                          : 'Aleatório',
                      visualDensity: compact ? VisualDensity.compact : null,
                      onPressed: player.toggleShuffle,
                      icon: const Icon(Icons.shuffle_rounded),
                      iconSize: compact ? 20 : 24,
                      color: player.isShuffling
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    IconButton(
                      tooltip: 'Anterior',
                      visualDensity: compact ? VisualDensity.compact : null,
                      onPressed: player.previous,
                      icon: const Icon(Icons.skip_previous_rounded),
                      iconSize: compact ? 32 : 38,
                    ),
                    _PlayButton(player: player, compact: compact),
                    IconButton(
                      tooltip: 'Próxima',
                      visualDensity: compact ? VisualDensity.compact : null,
                      onPressed: player.next,
                      icon: const Icon(Icons.skip_next_rounded),
                      iconSize: compact ? 32 : 38,
                    ),
                    IconButton(
                      tooltip: player.repeatLabel,
                      visualDensity: compact ? VisualDensity.compact : null,
                      onPressed: player.cycleRepeatMode,
                      icon: Icon(
                        player.loopMode == LoopMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                      ),
                      iconSize: compact ? 20 : 24,
                      color: player.loopMode == LoopMode.off
                          ? scheme.onSurfaceVariant
                          : scheme.primary,
                    ),
                  ],
                ),
              ),
              _BottomActions(player: player, song: song, compact: compact),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- artwork

class _Artwork extends StatelessWidget {
  const _Artwork({
    required this.song,
    required this.player,
    required this.compact,
    required this.swipeX,
    required this.flash,
    required this.flashForward,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onTap,
  });

  final Song song;
  final PlayerController player;
  final bool compact;
  final double swipeX;
  final String? flash;
  final bool flashForward;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<DragEndDetails> onDragEnd;
  final void Function(TapUpDetails details, double size)? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = math.min(
            constraints.maxWidth - (compact ? 28 : 64),
            constraints.maxHeight - 6,
          );
          if (available < 40) return const SizedBox.shrink();
          final size = available.clamp(40.0, 360.0).toDouble();
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: onTap == null
                    ? null
                    : (details) => onTap!(details, size),
                onHorizontalDragUpdate: (details) =>
                    onDragUpdate(details.delta.dx),
                onHorizontalDragEnd: onDragEnd,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  transform: Matrix4.translationValues(swipeX, 0, 0)
                    ..rotateZ(swipeX / 2200),
                  child: Hero(
                    tag: 'np-art',
                    child: SongArtwork(
                      song: song,
                      size: size,
                      radius: compact ? 20 : 28,
                      showShadow: true,
                    ),
                  ),
                ),
              ),
              if (flash != null)
                IgnorePointer(
                  child: _SeekFlash(label: flash!, forward: flashForward),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SeekFlash extends StatelessWidget {
  const _SeekFlash({required this.label, required this.forward});

  final String label;
  final bool forward;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            forward
                ? Icons.fast_forward_rounded
                : Icons.fast_rewind_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- top bar

class _TopBar extends StatelessWidget {
  const _TopBar({required this.player, required this.compact});

  final PlayerController player;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(6, compact ? 0 : 4, 6, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Fechar',
            visualDensity: compact ? VisualDensity.compact : null,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.expand_more_rounded, size: compact ? 26 : 30),
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
            visualDensity: compact ? VisualDensity.compact : null,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ListeningStatsScreen(),
              ),
            ),
            icon: const Icon(Icons.insights_rounded),
          ),
          IconButton(
            tooltip: 'Fila de reprodução',
            visualDensity: compact ? VisualDensity.compact : null,
            onPressed: () => showQueueSheet(context),
            icon: const Icon(Icons.queue_music_rounded),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- seek bar

class _SeekBar extends StatelessWidget {
  const _SeekBar({
    required this.player,
    required this.song,
    required this.compact,
    required this.dragMs,
    required this.onDrag,
    required this.onDragEnd,
  });

  final PlayerController player;
  final Song song;
  final bool compact;
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
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16),
              child: Slider(
                min: 0,
                max: maxMs,
                value: current,
                onChanged: onDrag,
                onChangeEnd: onDragEnd,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 28),
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

// ---------------------------------------------------------------- controls

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.player, required this.compact});

  final PlayerController player;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = compact ? 54.0 : 68.0;
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
            width: size,
            height: size,
            child: Icon(
              player.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              size: compact ? 30 : 38,
              color: scheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.player,
    required this.song,
    required this.compact,
  });

  final PlayerController player;
  final Song song;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 8 : 14,
        compact ? 2 : 6,
        compact ? 8 : 14,
        compact ? 4 : 10,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: width - (compact ? 16 : 28)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _BottomAction(
                icon: Icons.bedtime_outlined,
                label: _timerLabel(player),
                active: player.sleepRemaining != null ||
                    player.sleepAtTrackEnd,
                compact: compact,
                onTap: () => showSleepTimerSheet(context),
              ),
              _BottomAction(
                icon: Icons.queue_music_rounded,
                label: 'Fila',
                compact: compact,
                onTap: () => showQueueSheet(context),
              ),
              _BottomAction(
                icon: Icons.lyrics_outlined,
                label: 'Letras',
                compact: compact,
                onTap: () => showLyricsSheet(context, song),
              ),
              _BottomAction(
                icon: Icons.equalizer_rounded,
                label: compact ? 'EQ' : 'Equalizador',
                active: player.eqEnabled,
                compact: compact,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EqualizerScreen(),
                  ),
                ),
              ),
              _BottomAction(
                icon: Icons.info_outline_rounded,
                label: compact ? 'Info' : 'Detalhes',
                compact: compact,
                onTap: () => showSongInfoSheet(context, song),
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

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.compact,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool compact;
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
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 12,
            vertical: compact ? 4 : 7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: compact ? 19 : 22, color: color),
              SizedBox(height: compact ? 2 : 4),
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
