import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/player_controller.dart';
import '../widgets/song_list_view.dart';

/// Lista simples de faixas (pastas, resultados salvos, etc.).
class SongListScreen extends StatelessWidget {
  const SongListScreen({
    super.key,
    required this.title,
    required this.songs,
    this.subtitle,
    this.queueLabel,
  });

  final String title;
  final List<Song> songs;
  final String? subtitle;
  final String? queueLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final player = context.read<PlayerController>();
    final totalMs = songs.fold<int>(0, (sum, song) => sum + song.durationMs);
    final label = queueLabel ?? title;

    void play(int index) {
      player.playSongs(songs, index: index, label: label);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          if (songs.isNotEmpty) ...<Widget>[
            IconButton(
              tooltip: 'Tocar aleatoriamente',
              onPressed: () {
                final shuffled = List<Song>.of(songs)..shuffle();
                player.playSongs(shuffled, label: label);
              },
              icon: const Icon(Icons.shuffle_rounded),
            ),
            IconButton(
              tooltip: 'Tocar tudo',
              onPressed: () => play(0),
              icon: const Icon(Icons.play_arrow_rounded),
            ),
          ],
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (subtitle != null) ...<Widget>[
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        '${songs.length} faixa(s) • ${formatTotalDuration(totalMs)}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
}
