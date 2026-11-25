import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils.dart';
import '../../data/models.dart';
import '../../data/playlist_controller.dart';
import '../../state/player_controller.dart';
import '../widgets/app_snack.dart';
import '../widgets/song_artwork.dart';

enum _SongAction {
  play,
  playNext,
  addToQueue,
  favorite,
  addToPlaylist,
  info,
  removeFromPlaylist,
}

Future<void> showSongActions(
  BuildContext context,
  Song song, {
  String? playlistId,
  List<Song>? queue,
  String? queueLabel,
}) async {
  final player = context.read<PlayerController>();
  final profile = context.read<PlaylistController>();
  final action = await showModalBottomSheet<_SongAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _SongActionsSheet(
      song: song,
      canRemoveFromPlaylist: playlistId != null,
    ),
  );
  if (action == null) return;
  switch (action) {
    case _SongAction.play:
      await player.playSong(
        song,
        queue: queue,
        label: queueLabel ?? 'Seleção',
      );
      break;
    case _SongAction.favorite:
      profile.toggleFavorite(song);
      break;
    case _SongAction.playNext:
      await player.playNext(song);
      if (context.mounted) {
        showAppSnack(context, 'Vai tocar a seguir.');
      }
      break;
    case _SongAction.addToQueue:
      await player.addToQueue(song);
      if (context.mounted) {
        showAppSnack(context, 'Adicionada à fila.');
      }
      break;
    case _SongAction.addToPlaylist:
      if (context.mounted) {
        await showAddToPlaylistSheet(context, song);
      }
      break;
    case _SongAction.info:
      if (context.mounted) {
        await showSongInfoSheet(context, song);
      }
      break;
    case _SongAction.removeFromPlaylist:
      if (playlistId != null) {
        profile.removeSongFromPlaylist(playlistId, song.id);
        if (context.mounted) {
          showAppSnack(context, 'Removida da playlist.');
        }
      }
      break;
  }
}

class _SongActionsSheet extends StatelessWidget {
  const _SongActionsSheet({
    required this.song,
    required this.canRemoveFromPlaylist,
  });

  final Song song;
  final bool canRemoveFromPlaylist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isFavorite = context.select<PlaylistController, bool>(
      (controller) => controller.isFavorite(song.id),
    );

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: <Widget>[
                SongArtwork(song: song, size: 56, radius: 14),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.play_arrow_rounded),
            title: const Text('Tocar agora'),
            onTap: () => Navigator.of(context).pop(_SongAction.play),
          ),
          ListTile(
            leading: const Icon(Icons.playlist_play_rounded),
            title: const Text('Tocar a seguir'),
            onTap: () => Navigator.of(context).pop(_SongAction.playNext),
          ),
          ListTile(
            leading: const Icon(Icons.add_to_queue_rounded),
            title: const Text('Adicionar à fila'),
            onTap: () => Navigator.of(context).pop(_SongAction.addToQueue),
          ),
          ListTile(
            leading: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: isFavorite ? scheme.primary : null,
            ),
            title: Text(
              isFavorite ? 'Remover dos favoritos' : 'Adicionar aos favoritos',
            ),
            onTap: () => Navigator.of(context).pop(_SongAction.favorite),
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded),
            title: const Text('Adicionar a uma playlist'),
            onTap: () => Navigator.of(context).pop(_SongAction.addToPlaylist),
          ),
          if (canRemoveFromPlaylist)
            ListTile(
              leading: Icon(Icons.playlist_remove_rounded, color: scheme.error),
              title: Text(
                'Remover da playlist',
                style: TextStyle(color: scheme.error),
              ),
              onTap: () =>
                  Navigator.of(context).pop(_SongAction.removeFromPlaylist),
            ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Detalhes da faixa'),
            onTap: () => Navigator.of(context).pop(_SongAction.info),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- add to playlist

Future<void> showAddToPlaylistSheet(BuildContext context, Song song) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _AddToPlaylistSheet(song: song),
  );
}

class _AddToPlaylistSheet extends StatelessWidget {
  const _AddToPlaylistSheet({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = context.watch<PlaylistController>();

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Adicionar a uma playlist',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.add_rounded, color: scheme.primary),
              ),
              title: const Text('Nova playlist'),
              onTap: () async {
                final playlist = await showCreatePlaylistDialog(
                  context,
                  profile,
                  song: song,
                );
                if (playlist != null && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
            const Divider(),
            if (profile.playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: <Widget>[
                    Icon(
                      Icons.queue_music_rounded,
                      size: 40,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Nenhuma playlist ainda',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Crie uma para organizar suas faixas.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: profile.playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = profile.playlists[index];
                    final contains = playlist.songIds.contains(song.id);
                    return ListTile(
                      leading: Icon(
                        Icons.queue_music_rounded,
                        color: scheme.primary,
                      ),
                      title: Text(playlist.name),
                      subtitle: Text('${playlist.length} faixa(s)'),
                      trailing: contains
                          ? Icon(Icons.check_rounded, color: scheme.primary)
                          : const Icon(Icons.add_rounded),
                      onTap: contains
                          ? null
                          : () {
                              final added =
                                  profile.addSongs(playlist.id, <Song>[song]);
                              final messenger = ScaffoldMessenger.of(context);
                              Navigator.of(context).pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    added > 0
                                        ? 'Adicionada a ${playlist.name}.'
                                        : 'Já estava em ${playlist.name}.',
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
}

Future<Playlist?> showCreatePlaylistDialog(
  BuildContext context,
  PlaylistController profile, {
  Song? song,
}) {
  return showDialog<Playlist>(
    context: context,
    builder: (dialogContext) => _CreatePlaylistDialog(
      profile: profile,
      song: song,
    ),
  );
}

class _CreatePlaylistDialog extends StatefulWidget {
  const _CreatePlaylistDialog({required this.profile, this.song});

  final PlaylistController profile;
  final Song? song;

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _create() {
    final playlist = widget.profile.createPlaylist(_controller.text);
    if (widget.song != null) {
      widget.profile.addSongs(playlist.id, <Song>[widget.song!]);
    }
    Navigator.of(context).pop(playlist);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova playlist'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Nome da playlist'),
        onSubmitted: (_) => _create(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _create,
          child: const Text('Criar'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- song info

Future<void> showSongInfoSheet(BuildContext context, Song song) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _SongInfoSheet(song: song),
  );
}

class _SongInfoSheet extends StatelessWidget {
  const _SongInfoSheet({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final path = song.path?.isNotEmpty == true
        ? song.path!
        : song.contentUri;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  SongArtwork(song: song, size: 64, radius: 16),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          song.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _InfoRow(label: 'Álbum', value: song.album),
              _InfoRow(label: 'Formato', value: song.format),
              _InfoRow(
                label: 'Qualidade',
                value:
                    '${song.qualityLabel} • ${formatBitrate(song.bitrateKbps)}',
              ),
              _InfoRow(label: 'Duração', value: song.durationLabel),
              _InfoRow(label: 'Tamanho', value: formatBytes(song.sizeBytes)),
              if (song.year > 0)
                _InfoRow(label: 'Ano', value: song.year.toString()),
              if (song.track > 0)
                _InfoRow(label: 'Faixa', value: song.track.toString()),
              _InfoRow(label: 'Pasta', value: song.folder),
              _InfoRow(
                label: 'Adicionada em',
                value: formatDate(song.dateAddedMs),
              ),
              _InfoRow(label: 'Arquivo', value: path, selectable: true),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: path));
                  if (context.mounted) {
                    showAppSnack(context, 'Caminho copiado.');
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copiar caminho'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: selectable
                ? SelectableText(
                    value.isEmpty ? '—' : value,
                    style: theme.textTheme.bodySmall,
                  )
                : Text(
                    value.isEmpty ? '—' : value,
                    style: theme.textTheme.bodySmall,
                  ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- queue

Future<void> showQueueSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return _QueueView(scrollController: scrollController);
        },
      );
    },
  );
}

class _QueueView extends StatelessWidget {
  const _QueueView({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final player = context.watch<PlayerController>();
    final queue = player.queue;
    final origin = player.contextLabel.trim().isEmpty
        ? 'Seleção'
        : player.contextLabel;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 10),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Fila de reprodução', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      'Tocando de: $origin',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      player.queueLimited
                          ? '${queue.length} faixas • fila limitada para manter a fluidez'
                          : '${queue.length} faixa(s)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Restaurar fila',
                onPressed: player.canRestoreQueue
                    ? () => player.restoreQueue()
                    : null,
                icon: const Icon(Icons.settings_backup_restore_rounded),
              ),
              IconButton(
                tooltip: 'Limpar fila',
                onPressed: queue.length > 1
                    ? () => _clearQueue(context, player)
                    : null,
                icon: const Icon(Icons.playlist_remove_rounded),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: queue.isEmpty
              ? Center(
                  child: Text(
                    'A fila está vazia.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  scrollController: scrollController,
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: queue.length,
                  onReorderItem: (oldIndex, newIndex) {
                    if (newIndex == oldIndex) return;
                    player.moveQueueItem(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final song = queue[index];
                    final isCurrent = player.currentIndex == index;
                    return Material(
                      key: ValueKey<String>('queue-$index-${song.id}'),
                      color: isCurrent
                          ? scheme.primary.withValues(alpha: 0.08)
                          : Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          player.seekToIndex(index);
                          Navigator.of(context).pop();
                        },
                        child: SizedBox(
                          height: 62,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4, right: 4),
                            child: Row(
                              children: <Widget>[
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.drag_handle_rounded,
                                      size: 20,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 22,
                                  child: isCurrent
                                      ? Icon(
                                          Icons.graphic_eq_rounded,
                                          size: 16,
                                          color: scheme.primary,
                                        )
                                      : Text(
                                          '${index + 1}',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                ),
                                SongArtwork(song: song, size: 40, radius: 9),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        song.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: isCurrent
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isCurrent
                                              ? scheme.primary
                                              : scheme.onSurface,
                                        ),
                                      ),
                                      Text(
                                        song.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            theme.textTheme.labelSmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  song.durationLabel,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                if (!isCurrent)
                                  IconButton(
                                    tooltip: 'Remover da fila',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () =>
                                        player.removeQueueAt(index),
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                  )
                                else
                                  const SizedBox(width: 40),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static Future<void> _clearQueue(
    BuildContext context,
    PlayerController player,
  ) async {
    if (player.queue.length > 10) {
      final confirmed = await confirmAction(
        context,
        title: 'Limpar a fila?',
        message:
            'As faixas pendentes serão removidas. A faixa atual continua até o fim e depois a reprodução para.',
        confirmLabel: 'Limpar',
        destructive: true,
      );
      if (!confirmed) return;
    }
    await player.clearQueue();
  }
}

// --------------------------------------------------------------- sleep timer

Future<void> showSleepTimerSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => const _SleepTimerSheet(),
  );
}

class _SleepTimerSheet extends StatelessWidget {
  const _SleepTimerSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final player = context.watch<PlayerController>();
    final remaining = player.sleepRemaining;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Temporizador', style: theme.textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(
                  remaining != null
                      ? 'Desliga em ${_formatRemaining(remaining)}'
                      : 'Escolha quando a música deve parar.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          for (final minutes in <int>[5, 10, 15, 30, 45, 60])
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text('$minutes minutos'),
              onTap: () {
                player.setSleepTimer(Duration(minutes: minutes));
                Navigator.of(context).pop();
              },
            ),
          ListTile(
            leading: const Icon(Icons.music_off_rounded),
            title: const Text('Ao fim da faixa atual'),
            trailing: player.sleepAtTrackEnd
                ? Icon(Icons.check_rounded, color: scheme.primary)
                : null,
            onTap: () {
              player.setSleepAtTrackEnd(true);
              Navigator.of(context).pop();
            },
          ),
          if (remaining != null || player.sleepAtTrackEnd)
            ListTile(
              leading: Icon(Icons.timer_off_outlined, color: scheme.error),
              title: Text(
                'Desativar temporizador',
                style: TextStyle(color: scheme.error),
              ),
              onTap: () {
                player.setSleepTimer(null);
                player.setSleepAtTrackEnd(false);
                Navigator.of(context).pop();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
      ),
    );
  }

  static String _formatRemaining(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
