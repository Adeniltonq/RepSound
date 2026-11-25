import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils.dart';
import '../../data/models.dart';
import '../../data/style_controller.dart';
import '../../data/style_models.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../sheets/style_sheets.dart';
import '../widgets/app_snack.dart';
import '../widgets/common.dart';
import '../widgets/song_list_view.dart';

/// Gerencia os estilos do usuário (nome + cor).
class StylesScreen extends StatelessWidget {
  const StylesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final styles = context.watch<StyleController>();
    final library = context.watch<LibraryController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estilos'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Novo estilo',
            onPressed: () => showStyleEditor(context, styles),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showStyleEditor(context, styles),
        icon: const Icon(Icons.palette_rounded),
        label: const Text('Novo estilo'),
      ),
      body: styles.styles.isEmpty
          ? EmptyState(
              icon: Icons.palette_outlined,
              title: 'Nenhum estilo ainda',
              message:
                  'Crie estilos como “Rock”, “Trabalho” ou “Corrida” e aplique '
                  'em faixas, álbuns ou artistas. Cada estilo vira uma '
                  'playlist automática na Home.',
              actionLabel: 'Criar estilo',
              onAction: () => showStyleEditor(context, styles),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: styles.styles.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.auto_awesome_rounded,
                              color: scheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Cada estilo com faixas vira uma playlist '
                              'automática na Home e pode alimentar a Daily.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final style = styles.styles[index - 1];
                final count = styles.songsWithStyle(library.songs, style.id).length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: theme.brightness == Brightness.dark
                        ? scheme.surfaceContainerLow
                        : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => StyleSongsScreen(style: style),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Color(style.colorValue).withValues(
                                  alpha: 0.18,
                                ),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                Icons.palette_rounded,
                                color: Color(style.colorValue),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    style.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$count faixa(s)',
                                    style:
                                        theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Editar',
                              onPressed: () =>
                                  showStyleEditor(context, styles, style: style),
                              icon: const Icon(Icons.edit_rounded, size: 20),
                            ),
                            IconButton(
                              tooltip: 'Excluir',
                              color: scheme.error,
                              onPressed: () async {
                                final confirmed = await confirmAction(
                                  context,
                                  title: 'Excluir estilo?',
                                  message:
                                      '“${style.name}” será removido de todas as faixas. '
                                      'Os arquivos não são apagados.',
                                  confirmLabel: 'Excluir',
                                  destructive: true,
                                );
                                if (!confirmed) return;
                                styles.delete(style.id);
                                if (context.mounted) {
                                  showAppSnack(context, 'Estilo excluído.');
                                }
                              },
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class StyleSongsScreen extends StatelessWidget {
  const StyleSongsScreen({super.key, required this.style});

  final SongStyle style;

  @override
  Widget build(BuildContext context) {
    final styles = context.watch<StyleController>();
    final library = context.watch<LibraryController>();
    final player = context.read<PlayerController>();
    final songs = styles.songsWithStyle(library.songs, style.id);
    final totalMs = songs.fold<int>(0, (sum, song) => sum + song.durationMs);
    final label = 'Estilo • ${style.name}';

    return Scaffold(
      appBar: AppBar(
        title: Text(style.name),
        actions: <Widget>[
          IconButton(
            tooltip: 'Tocar tudo',
            onPressed: songs.isEmpty
                ? null
                : () => player.playSongs(songs, label: label),
            icon: const Icon(Icons.play_arrow_rounded),
          ),
          IconButton(
            tooltip: 'Aleatório',
            onPressed: songs.isEmpty
                ? null
                : () {
                    final shuffled = List<Song>.of(songs)..shuffle();
                    player.playSongs(shuffled, label: label);
                  },
            icon: const Icon(Icons.shuffle_rounded),
          ),
          IconButton(
            tooltip: 'Editar estilo',
            onPressed: () => showStyleEditor(context, styles, style: style),
            icon: const Icon(Icons.edit_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Text(
              '${songs.length} faixa(s) • ${formatTotalDuration(totalMs)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                icon: Icons.palette_outlined,
                title: 'Estilo vazio',
                message:
                    'Aplique “${style.name}” em faixas, álbuns ou artistas '
                    'para preencher esta playlist automática.',
                compact: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
