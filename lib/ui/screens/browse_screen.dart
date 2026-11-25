import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/library_controller.dart';
import '../widgets/common.dart';
import 'song_list_screen.dart';

/// Navegação por álbuns, artistas e pastas.
class BrowseScreen extends StatelessWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      bottom: false,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Navegar',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Álbuns, artistas e pastas da sua biblioteca.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const TabBar(
              tabs: <Widget>[
                Tab(text: 'Álbuns'),
                Tab(text: 'Artistas'),
                Tab(text: 'Pastas'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: <Widget>[
                  _GroupsView(kind: _BrowseKind.album),
                  _GroupsView(kind: _BrowseKind.artist),
                  _GroupsView(kind: _BrowseKind.folder),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _BrowseKind { album, artist, folder }

class _GroupEntry {
  const _GroupEntry({
    required this.title,
    required this.subtitle,
    required this.songs,
  });

  final String title;
  final String subtitle;
  final List<Song> songs;
}

class _GroupsView extends StatelessWidget {
  const _GroupsView({required this.kind});

  final _BrowseKind kind;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final groups = _group(library.songs, kind);
    if (groups.isEmpty) {
      return EmptyState(
        icon: switch (kind) {
          _BrowseKind.album => Icons.album_rounded,
          _BrowseKind.artist => Icons.person_rounded,
          _BrowseKind.folder => Icons.folder_rounded,
        },
        title: 'Nada para navegar',
        message: 'A biblioteca ainda não tem itens suficientes.',
        compact: true,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 28),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final entry = groups[index];
        return _GroupTile(entry: entry, kind: kind);
      },
    );
  }

  static List<_GroupEntry> _group(List<Song> songs, _BrowseKind kind) {
    final map = <String, List<Song>>{};
    for (final song in songs) {
      final key = switch (kind) {
        _BrowseKind.album => '${song.artistKey}|${song.albumKey}',
        _BrowseKind.artist => song.artistKey,
        _BrowseKind.folder => song.folderKey,
      };
      map.putIfAbsent(key, () => <Song>[]).add(song);
    }
    final result = <_GroupEntry>[
      for (final entry in map.entries)
        _GroupEntry(
          title: switch (kind) {
            _BrowseKind.album => entry.value.first.album,
            _BrowseKind.artist => entry.value.first.artist,
            _BrowseKind.folder => entry.value.first.folder,
          },
          subtitle: switch (kind) {
            _BrowseKind.album => entry.value.first.artist,
            _BrowseKind.artist => '${entry.value.length} faixa(s)',
            _BrowseKind.folder => '${entry.value.length} faixa(s)',
          },
          songs: entry.value,
        ),
    ];
    result.sort(
      (a, b) => normalizeForSearch(a.title).compareTo(
        normalizeForSearch(b.title),
      ),
    );
    return result;
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.entry, required this.kind});

  final _GroupEntry entry;
  final _BrowseKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final totalMs = entry.songs.fold<int>(0, (sum, song) => sum + song.durationMs);
    final label = switch (kind) {
      _BrowseKind.album => 'Álbum • ${entry.title}',
      _BrowseKind.artist => 'Artista • ${entry.title}',
      _BrowseKind.folder => entry.title,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: theme.brightness == Brightness.dark
            ? scheme.surfaceContainerLow
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SongListScreen(
                title: entry.title,
                subtitle: kind == _BrowseKind.album ? entry.subtitle : null,
                songs: entry.songs,
                queueLabel: label,
              ),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: <Widget>[
                CollectionCover(
                  songs: entry.songs,
                  size: 56,
                  radius: 13,
                  icon: switch (kind) {
                    _BrowseKind.album => Icons.album_rounded,
                    _BrowseKind.artist => Icons.person_rounded,
                    _BrowseKind.folder => Icons.folder_rounded,
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${entry.subtitle} • ${entry.songs.length} faixa(s) • '
                        '${formatTotalDuration(totalMs)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
