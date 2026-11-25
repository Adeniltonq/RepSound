import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils.dart';
import '../../data/models.dart';
import '../../data/playlist_controller.dart';
import '../../state/library_controller.dart';
import '../sheets/playlist_sheets.dart';
import '../sheets/song_sheets.dart';
import '../widgets/app_snack.dart';
import '../widgets/common.dart';
import 'collection_screen.dart';
import 'playlist_detail_screen.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PlaylistController>();
    final library = context.watch<LibraryController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 10, 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Playlists',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${profile.playlistCount} playlist(s) • '
                        '${profile.favoriteCount} favorito(s)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Nova playlist',
                  onPressed: () => _create(context, profile),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          SectionHeader(
            title: 'Coleções',
            subtitle: 'Atualizadas automaticamente',
          ),
          SizedBox(
            height: 112,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: <Widget>[
                _CollectionCard(
                  kind: SongCollectionKind.favorites,
                  icon: Icons.favorite_rounded,
                  count: library.collectionCount(SongCollectionKind.favorites),
                  color: scheme.primary,
                  onTap: () => _openCollection(
                    context,
                    SongCollectionKind.favorites,
                  ),
                ),
                _CollectionCard(
                  kind: SongCollectionKind.recent,
                  icon: Icons.history_rounded,
                  count: library.collectionCount(SongCollectionKind.recent),
                  color: const Color(0xFF22D3EE),
                  onTap: () => _openCollection(
                    context,
                    SongCollectionKind.recent,
                  ),
                ),
                _CollectionCard(
                  kind: SongCollectionKind.mostPlayed,
                  icon: Icons.trending_up_rounded,
                  count: library.collectionCount(SongCollectionKind.mostPlayed),
                  color: const Color(0xFF10B981),
                  onTap: () => _openCollection(
                    context,
                    SongCollectionKind.mostPlayed,
                  ),
                ),
                _CollectionCard(
                  kind: SongCollectionKind.recentlyAdded,
                  icon: Icons.new_releases_rounded,
                  count:
                      library.collectionCount(SongCollectionKind.recentlyAdded),
                  color: const Color(0xFFF59E0B),
                  onTap: () => _openCollection(
                    context,
                    SongCollectionKind.recentlyAdded,
                  ),
                ),
              ],
            ),
          ),
          SectionHeader(
            title: 'Suas playlists',
            subtitle: profile.playlists.isEmpty
                ? 'Crie a primeira para organizar suas faixas'
                : '${profile.playlists.length} playlist(s) personalizada(s)',
            actionLabel: 'Nova',
            onAction: () => _create(context, profile),
          ),
          if (profile.playlists.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: EmptyState(
                icon: Icons.queue_music_rounded,
                title: 'Nenhuma playlist ainda',
                message:
                    'Monte coleções do seu jeito: para treinar, viajar ou aquela seleção perfeita.',
                actionLabel: 'Criar playlist',
                onAction: () => _create(context, profile),
                compact: true,
              ),
            )
          else
            for (final playlist in profile.playlists)
              _PlaylistTile(
                playlist: playlist,
                songs: _songsOf(playlist, library),
                onOpen: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlaylistDetailScreen(
                      playlistId: playlist.id,
                    ),
                  ),
                ),
                onRename: () =>
                    showRenamePlaylistDialog(context, profile, playlist),
                onDelete: () => confirmDeletePlaylist(context, profile, playlist),
              ),
        ],
      ),
    );
  }

  static List<Song> _songsOf(Playlist playlist, LibraryController library) {
    final songs = <Song>[];
    for (final id in playlist.songIds) {
      final song = library.byId(id);
      if (song != null) songs.add(song);
    }
    return songs;
  }

  static Future<void> _create(
    BuildContext context,
    PlaylistController profile,
  ) async {
    final playlist = await showCreatePlaylistDialog(context, profile);
    if (playlist != null && context.mounted) {
      showAppSnack(context, 'Playlist “${playlist.name}” criada.');
    }
  }

  static void _openCollection(BuildContext context, SongCollectionKind kind) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CollectionScreen(kind: kind),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.kind,
    required this.icon,
    required this.count,
    required this.color,
    required this.onTap,
  });

  final SongCollectionKind kind;
  final IconData icon;
  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        width: 164,
        child: Material(
          color: theme.brightness == Brightness.dark
              ? scheme.surfaceContainerLow
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(icon, size: 19, color: color),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    kind.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count faixa(s)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.playlist,
    required this.songs,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final Playlist playlist;
  final List<Song> songs;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final totalMs = songs.fold<int>(0, (sum, song) => sum + song.durationMs);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: theme.brightness == Brightness.dark
            ? scheme.surfaceContainerLow
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onOpen,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: <Widget>[
                CollectionCover(
                  songs: songs,
                  size: 58,
                  radius: 14,
                  icon: Icons.queue_music_rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${songs.length} faixa(s) • '
                        '${formatTotalDuration(totalMs)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opções',
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (value) {
                    if (value == 'rename') onRename();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const <PopupMenuEntry<String>>[
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
                        title: Text('Excluir'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
