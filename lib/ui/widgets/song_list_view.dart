import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/media_channel.dart';
import '../../data/models.dart';
import '../../data/playlist_controller.dart';
import '../../data/song_card_cache.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../../state/settings_controller.dart';
import '../sheets/style_sheets.dart';
import 'app_snack.dart';
import 'common.dart';
import 'song_tile.dart';

typedef SongTapCallback = void Function(Song song, int index);

/// Lista de faixas com carregamento em janela e seleção múltipla.
///
/// A quantidade visível é medida de verdade (altura/largura da viewport) e
/// repassada ao [SongCardCache], que mantém no máximo 4× esse número de capas
/// em memória. Ao rolar, as fichas antigas saem e as novas entram.
///
/// Um toque longo ativa a seleção; com ela ativa, tocar marca/desmarca.
class SongListView extends StatefulWidget {
  const SongListView({
    super.key,
    required this.songs,
    required this.onTap,
    this.viewMode,
    this.columns,
    this.playlistId,
    this.queueLabel,
    this.padding = const EdgeInsets.only(bottom: 28),
    this.controller,
    this.empty,
    this.selectionEnabled = true,
  });

  final List<Song> songs;
  final SongTapCallback onTap;
  final ViewMode? viewMode;
  final int? columns;
  final String? playlistId;
  final String? queueLabel;
  final EdgeInsets padding;
  final ScrollController? controller;
  final Widget? empty;
  final bool selectionEnabled;

  @override
  State<SongListView> createState() => _SongListViewState();
}

class _SongListViewState extends State<SongListView> {
  int _lastVisible = -1;
  final Set<String> _selected = <String>{};
  bool _selecting = false;

  void _syncVisible(int visible) {
    final clamped = visible.clamp(1, 400);
    if (clamped == _lastVisible) return;
    _lastVisible = clamped;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SongCardCache>().setVisibleCount(clamped);
    });
  }

  List<Song> get _selectedSongs => <Song>[
        for (final song in widget.songs)
          if (_selected.contains(song.id)) song,
      ];

  void _startSelection(Song song) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selecting = true;
      _selected.add(song.id);
    });
  }

  void _toggle(Song song) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.remove(song.id)) _selected.add(song.id);
      if (_selected.isEmpty) _selecting = false;
    });
  }

  void _cancelSelection() {
    setState(() {
      _selected.clear();
      _selecting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final songs = widget.songs;
    if (songs.isEmpty) {
      return widget.empty ??
          const EmptyState(
            icon: Icons.music_off_rounded,
            title: 'Nada por aqui',
            message: 'Nenhuma faixa encontrada nesta seleção.',
            compact: true,
          );
    }

    final settings = context.watch<SettingsController>();
    final mode = widget.viewMode ?? settings.viewMode;
    final columns = widget.columns ?? settings.gridColumns;

    final list = LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        if (mode == ViewMode.grid) {
          const spacing = 10.0;
          const horizontal = 16.0;
          final cell = (width - horizontal * 2 - spacing * (columns - 1)) /
              columns;
          final tileHeight = cell + 86;
          final rows = (height / tileHeight).ceil() + 1;
          _syncVisible(rows * columns);

          return GridView.builder(
            controller: widget.controller,
            padding: EdgeInsets.fromLTRB(
              horizontal,
              6,
              horizontal,
              _selecting ? 120 : widget.padding.bottom,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: cell / tileHeight,
            ),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return SongGridCard(
                key: ValueKey<String>(song.id),
                song: song,
                onTap: () => _handleTap(song, index),
                playlistId: widget.playlistId,
                queue: songs,
                queueLabel: widget.queueLabel,
                selecting: _selecting,
                selected: _selected.contains(song.id),
                onSelectionTap: () => _toggle(song),
                onSelectionLongPress: () => _startSelection(song),
              );
            },
          );
        }

        final compact = mode == ViewMode.compact;
        final itemHeight = compact ? 34.0 : 66.0;
        _syncVisible((height / itemHeight).ceil() + 1);
        final padding = _selecting
            ? widget.padding.copyWith(bottom: 120)
            : widget.padding;

        return ListView.builder(
          controller: widget.controller,
          padding: padding,
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            if (compact) {
              return CompactSongTile(
                key: ValueKey<String>(song.id),
                song: song,
                onTap: () => _handleTap(song, index),
                playlistId: widget.playlistId,
                queue: songs,
                queueLabel: widget.queueLabel,
                selecting: _selecting,
                selected: _selected.contains(song.id),
                onSelectionTap: () => _toggle(song),
                onSelectionLongPress: () => _startSelection(song),
              );
            }
            return SongTile(
              key: ValueKey<String>(song.id),
              song: song,
              onTap: () => _handleTap(song, index),
              playlistId: widget.playlistId,
              queue: songs,
              queueLabel: widget.queueLabel,
              selecting: _selecting,
              selected: _selected.contains(song.id),
              onSelectionTap: () => _toggle(song),
              onSelectionLongPress: () => _startSelection(song),
            );
          },
        );
      },
    );

    if (!widget.selectionEnabled) return list;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        list,
        if (_selecting)
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: _SelectionBar(
              count: _selected.length,
              allSelected: _selected.length == songs.length,
              onClose: _cancelSelection,
              onSelectAll: () {
                setState(() {
                  if (_selected.length == songs.length) {
                    _selected.clear();
                  } else {
                    _selected.addAll(songs.map((song) => song.id));
                  }
                });
              },
              onQueue: _queueSelected,
              onPlayNext: _playNextSelected,
              onPlaylist: _addToPlaylist,
              onStyle: _applyStyle,
              onDelete: _deleteSelected,
            ),
          ),
      ],
    );
  }

  void _handleTap(Song song, int index) {
    if (_selecting) {
      _toggle(song);
    } else {
      widget.onTap(song, index);
    }
  }

  Future<void> _queueSelected() async {
    final songs = _selectedSongs;
    if (songs.isEmpty) return;
    final player = context.read<PlayerController>();
    for (final song in songs) {
      await player.addToQueue(song);
    }
    if (!mounted) return;
    showAppSnack(context, '${songs.length} faixa(s) adicionada(s) à fila.');
    _cancelSelection();
  }

  Future<void> _playNextSelected() async {
    final songs = _selectedSongs;
    if (songs.isEmpty) return;
    final player = context.read<PlayerController>();
    for (final song in songs.reversed) {
      await player.playNext(song);
    }
    if (!mounted) return;
    showAppSnack(context, '${songs.length} faixa(s) tocam a seguir.');
    _cancelSelection();
  }

  Future<void> _addToPlaylist() async {
    final songs = _selectedSongs;
    if (songs.isEmpty) return;
    await showAddSongsToPlaylistSheet(context, songs: songs);
    if (mounted) _cancelSelection();
  }

  Future<void> _applyStyle() async {
    final songs = _selectedSongs;
    if (songs.isEmpty) return;
    await showApplyStylesSheet(context, songs: songs);
    if (mounted) _cancelSelection();
  }

  Future<void> _deleteSelected() async {
    final songs = _selectedSongs;
    if (songs.isEmpty) return;
    final confirmed = await confirmAction(
      context,
      title: 'Excluir ${songs.length} faixa(s)?',
      message:
          'Os arquivos serão apagados do aparelho. Dependendo do Android, o '
          'sistema pedirá uma confirmação extra. Esta ação não pode ser desfeita.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final library = context.read<LibraryController>();
    final profile = context.read<PlaylistController>();
    try {
      final deleted = await library.deleteSongs(songs);
      if (!mounted) return;
      profile.purgeSongs(<String>{for (final song in songs) song.id});
      _cancelSelection();
      showAppSnack(context, '$deleted arquivo(s) excluído(s).');
    } on MediaException catch (error) {
      if (!mounted) return;
      showAppSnack(context, error.message);
    } catch (error) {
      if (!mounted) return;
      showAppSnack(context, 'Não foi possível excluir: $error');
    }
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.allSelected,
    required this.onClose,
    required this.onSelectAll,
    required this.onQueue,
    required this.onPlayNext,
    required this.onPlaylist,
    required this.onStyle,
    required this.onDelete,
  });

  final int count;
  final bool allSelected;
  final VoidCallback onClose;
  final VoidCallback onSelectAll;
  final VoidCallback onQueue;
  final VoidCallback onPlayNext;
  final VoidCallback onPlaylist;
  final VoidCallback onStyle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(20),
      color: theme.brightness == Brightness.dark
          ? scheme.surfaceContainerHigh
          : Colors.white,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Cancelar seleção',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
                Expanded(
                  child: Text(
                    '$count selecionada(s)',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onSelectAll,
                  child: Text(allSelected ? 'Limpar' : 'Tudo'),
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: <Widget>[
                  _BarAction(
                    icon: Icons.add_to_queue_rounded,
                    label: 'Fila',
                    onTap: onQueue,
                  ),
                  _BarAction(
                    icon: Icons.playlist_play_rounded,
                    label: 'A seguir',
                    onTap: onPlayNext,
                  ),
                  _BarAction(
                    icon: Icons.playlist_add_rounded,
                    label: 'Playlist',
                    onTap: onPlaylist,
                  ),
                  _BarAction(
                    icon: Icons.palette_rounded,
                    label: 'Estilo',
                    onTap: onStyle,
                  ),
                  _BarAction(
                    icon: Icons.delete_outline_rounded,
                    label: 'Excluir',
                    color: scheme.error,
                    onTap: onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  const _BarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = color ?? scheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 21, color: tint),
              const SizedBox(height: 3),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(color: tint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
