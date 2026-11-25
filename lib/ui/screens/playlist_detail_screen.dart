import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils.dart';
import '../../data/models.dart';
import '../../data/playlist_controller.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../sheets/playlist_sheets.dart';
import '../widgets/common.dart';
import '../widgets/song_tile.dart';

class PlaylistDetailScreen extends StatelessWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PlaylistController>();
    final library = context.watch<LibraryController>();
    final player = context.read<PlayerController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final playlist = profile.playlistById(playlistId);

    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.playlist_remove_rounded,
          title: 'Playlist removida',
          message: 'Esta playlist não existe mais.',
        ),
      );
    }

    final songs = <Song>[];
    for (final id in playlist.songIds) {
      final song = library.byId(id);
      if (song != null) songs.add(song);
    }
    final totalMs = songs.fold<int>(0, (sum, song) => sum + song.durationMs);

    void play(int index) {
      player.playSongs(songs, index: index, label: playlist.name);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlist'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Adicionar músicas',
            onPressed: () =>
                showAddSongsSheet(context, playlistId: playlist.id),
            icon: const Icon(Icons.playlist_add_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opções',
            onSelected: (value) async {
              switch (value) {
                case 'add':
                  await showAddSongsSheet(context, playlistId: playlist.id);
                  break;
                case 'rename':
                  await showRenamePlaylistDialog(context, profile, playlist);
                  break;
                case 'delete':
                  await confirmDeletePlaylist(context, profile, playlist);
                  if (context.mounted &&
                      profile.playlistById(playlist.id) == null) {
                    Navigator.of(context).pop();
                  }
                  break;
              }
            },
            itemBuilder: (context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'add',
                child: ListTile(
                  leading: Icon(Icons.playlist_add_rounded),
                  title: Text('Adicionar músicas'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<String>(
                value: 'rename',
                child: ListTile(
                  leading: Icon(Icons.edit_rounded),
                  title: Text('Renomear'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('Excluir playlist'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    scheme.primary.withValues(alpha: 0.22),
                    scheme.primary.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: <Widget>[
                  CollectionCover(
                    songs: songs,
                    size: 96,
                    radius: 20,
                    icon: Icons.queue_music_rounded,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          playlist.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${songs.length} faixa(s) • '
                          '${formatTotalDuration(totalMs)}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            FilledButton.icon(
                              onPressed: songs.isEmpty ? null : () => play(0),
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                size: 18,
                              ),
                              label: const Text('Tocar'),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Aleatório',
                              onPressed: songs.isEmpty
                                  ? null
                                  : () {
                                      final shuffled = List<Song>.of(songs)
                                        ..shuffle();
                                      player.playSongs(
                                        shuffled,
                                        label: playlist.name,
                                      );
                                    },
                              icon: const Icon(Icons.shuffle_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (songs.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.drag_indicator_rounded,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Segure e arraste para reordenar',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '${songs.length} faixas',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: songs.isEmpty
                ? EmptyState(
                    icon: Icons.queue_music_rounded,
                    title: 'Playlist vazia',
                    message:
                        'Adicione faixas da sua biblioteca para começar a montar esta seleção.',
                    actionLabel: 'Adicionar músicas',
                    onAction: () =>
                        showAddSongsSheet(context, playlistId: playlist.id),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 28),
                    itemCount: songs.length,
                    onReorderItem: (oldIndex, newIndex) =>
                        profile.movePlaylistSong(
                      playlist.id,
                      oldIndex,
                      newIndex,
                    ),
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      return ColoredBox(
                        key: ValueKey<String>(song.id),
                        color: theme.scaffoldBackgroundColor,
                        child: SongTile(
                          song: song,
                          enableLongPress: false,
                          playlistId: playlist.id,
                          queue: songs,
                          queueLabel: playlist.name,
                          onTap: () => play(index),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
