import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils.dart';
import '../../data/models.dart';
import '../../data/playlist_controller.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../widgets/common.dart';
import '../widgets/song_list_view.dart';

/// Coleções automáticas: favoritos, recentes, mais ouvidas e novidades.
class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key, required this.kind});

  final SongCollectionKind kind;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    context.watch<PlaylistController>();
    final player = context.read<PlayerController>();
    final songs = library.collectionSongs(kind);
    final totalMs = songs.fold<int>(0, (sum, song) => sum + song.durationMs);
    final label = kind.label;

    void play(int index) {
      player.playSongs(songs, index: index, label: label);
    }

    return Scaffold(
      appBar: AppBar(title: Text(kind.label)),
      body: songs.isEmpty
          ? EmptyState(
              icon: _iconFor(kind),
              title: 'Ainda não há faixas aqui',
              message: kind.description,
            )
          : Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.24),
                          Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.06),
                        ],
                      ),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.20),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        CollectionCover(
                          songs: songs,
                          size: 84,
                          radius: 18,
                          icon: _iconFor(kind),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                kind.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${songs.length} faixa(s) • ${formatTotalDuration(totalMs)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: <Widget>[
                                  FilledButton.icon(
                                    onPressed: () => play(0),
                                    icon: const Icon(
                                      Icons.play_arrow_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Tocar'),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Aleatório',
                                    onPressed: () {
                                      final shuffled = List<Song>.of(songs)
                                        ..shuffle();
                                      player.playSongs(
                                        shuffled,
                                        label: label,
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
                Expanded(
                  child: SongListView(
                    songs: songs,
                    queueLabel: label,
                    onTap: (song, index) => play(index),
                  ),
                ),
              ],
            ),
    );
  }

  static IconData _iconFor(SongCollectionKind kind) => switch (kind) {
        SongCollectionKind.favorites => Icons.favorite_rounded,
        SongCollectionKind.recent => Icons.history_rounded,
        SongCollectionKind.mostPlayed => Icons.trending_up_rounded,
        SongCollectionKind.recentlyAdded => Icons.new_releases_rounded,
      };
}
