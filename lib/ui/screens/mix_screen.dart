import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils.dart';
import '../../data/models.dart';
import '../../data/playlist_controller.dart';
import '../../data/recommendation_service.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../widgets/app_snack.dart';
import '../widgets/common.dart';
import '../widgets/song_list_view.dart';

enum MixKind { favorites, discoveries }

extension MixKindInfo on MixKind {
  String get title => switch (this) {
        MixKind.favorites => 'Mix Favoritas',
        MixKind.discoveries => 'Descobertas',
      };

  String get subtitle => switch (this) {
        MixKind.favorites =>
          'Sorteio ponderado pelas suas favoritas, artistas e histórico.',
        MixKind.discoveries =>
          'Metade nunca ouvida, 30% de artistas favoritos e 20% antigas.',
      };
}

/// Lista gerada de recomendações. “Atualizar” sorteia novamente.
class MixScreen extends StatefulWidget {
  const MixScreen({super.key, required this.kind});

  final MixKind kind;

  @override
  State<MixScreen> createState() => _MixScreenState();
}

class _MixScreenState extends State<MixScreen> {
  List<Song>? _songs;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _generate();
  }

  void _generate() {
    final library = context.read<LibraryController>();
    final profile = context.read<PlaylistController>();
    setState(() {
      _songs = switch (widget.kind) {
        MixKind.favorites =>
          RecommendationService.mixFavorites(library.songs, profile),
        MixKind.discoveries =>
          RecommendationService.discoveries(library.songs, profile),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final player = context.read<PlayerController>();
    final songs = _songs ?? const <Song>[];
    final label = widget.kind.title;
    final totalMs = songs.fold<int>(0, (sum, song) => sum + song.durationMs);

    return Scaffold(
      appBar: AppBar(
        title: Text(label),
        actions: <Widget>[
          IconButton(
            tooltip: 'Atualizar sugestões',
            onPressed: _generate,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.kind.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: songs.isEmpty
                            ? null
                            : () => player.playSongs(songs, label: label),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Tocar'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: songs.isEmpty
                            ? null
                            : () {
                                final shuffled = List<Song>.of(songs)
                                  ..shuffle();
                                player.playSongs(shuffled, label: label);
                              },
                        icon: const Icon(Icons.shuffle_rounded, size: 18),
                        label: const Text('Aleatório'),
                      ),
                      const Spacer(),
                      Text(
                        '${songs.length} • ${formatTotalDuration(totalMs)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SongListView(
              songs: songs,
              queueLabel: label,
              onTap: (song, index) =>
                  player.playSongs(songs, index: index, label: label),
              empty: EmptyState(
                icon: Icons.auto_awesome_rounded,
                title: 'Sem sugestões ainda',
                message:
                    'Ouça algumas faixas e adicione favoritos para o RepSound '
                    'aprender seu gosto. Toque em atualizar para tentar de novo.',
                compact: true,
                actionLabel: 'Atualizar',
                onAction: () {
                  _generate();
                  if (context.mounted) {
                    showAppSnack(context, 'Sugestões atualizadas.');
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
