import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/lyrics_service.dart';
import '../../data/models.dart';
import '../../state/player_controller.dart';

/// Painel de letras integrado à reprodução (`.lrc` sincronizado ou `.txt`).
Future<void> showLyricsSheet(BuildContext context, Song song) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _LyricsSheet(song: song),
  );
}

class _LyricsSheet extends StatefulWidget {
  const _LyricsSheet({required this.song});

  final Song song;

  @override
  State<_LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<_LyricsSheet> {
  Lyrics? _lyrics;
  bool _loading = true;
  final ScrollController _scroll = ScrollController();
  final List<GlobalKey> _lineKeys = <GlobalKey>[];
  int _lastActive = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() => _loading = true);
    final lyrics = await LyricsService.load(widget.song, refresh: refresh);
    if (!mounted) return;
    setState(() {
      _lyrics = lyrics;
      _loading = false;
      _lineKeys.clear();
      _lastActive = -1;
    });
  }

  /// Mantém a linha ativa visível, sem brigar com a rolagem manual.
  void _followActive(int active) {
    if (active == _lastActive) return;
    _lastActive = active;
    if (active < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final context = active < _lineKeys.length
          ? _lineKeys[active].currentContext
          : null;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.42,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      } else {
        final target = (active * 54.0).clamp(
          0.0,
          _scroll.position.maxScrollExtent,
        );
        _scroll.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final player = context.watch<PlayerController>();
    final lyrics = _lyrics;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text('Letras',
                                style: theme.textTheme.titleLarge),
                            if (lyrics != null && lyrics.synced) ...<Widget>[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      scheme.primary.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'SINCRONIZADA',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 9,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${widget.song.title} • ${widget.song.artist}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Recarregar letra',
                    onPressed: _loading ? null : () => _load(refresh: true),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : lyrics == null
                      ? _missing(theme, scheme)
                      : StreamBuilder<Duration>(
                          stream: player.positionStream,
                          builder: (context, snapshot) {
                            final position =
                                snapshot.data ?? Duration.zero;
                            final active = LyricsService.activeLine(
                              lyrics,
                              position,
                            );
                            _followActive(active);
                            return ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                18,
                                24,
                                32,
                              ),
                              itemCount: lyrics.lines.length,
                              itemBuilder: (context, index) {
                                while (_lineKeys.length <= index) {
                                  _lineKeys.add(GlobalKey());
                                }
                                final line = lyrics.lines[index];
                                final isActive = index == active;
                                return Padding(
                                  key: _lineKeys[index],
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Text(
                                    line.text,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                      color: isActive
                                          ? scheme.primary
                                          : scheme.onSurface.withValues(
                                              alpha: 0.72,
                                            ),
                                      fontWeight: isActive
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      height: 1.5,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _missing(ThemeData theme, ColorScheme scheme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.lyrics_outlined, size: 46, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('Nenhuma letra encontrada',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Coloque um arquivo .lrc (sincronizado) ou .txt com o mesmo '
              'nome da música na mesma pasta do áudio. Exemplo:\n'
              '${widget.song.path ?? widget.song.title}.lrc',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
