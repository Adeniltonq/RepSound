import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils.dart';
import '../../data/daily_controller.dart';
import '../../data/models.dart';
import '../../data/playlist_controller.dart';
import '../../data/style_controller.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../widgets/app_snack.dart';
import '../widgets/common.dart';
import 'styles_screen.dart';

/// Playlist do dia: estilos escolhidos + Mix Favoritas/Descobertas.
class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final daily = context.watch<DailyController>();
    final styles = context.watch<StyleController>();
    final library = context.watch<LibraryController>();
    final profile = context.watch<PlaylistController>();
    final player = context.read<PlayerController>();

    final byId = <String, Song>{for (final song in library.songs) song.id: song};
    final songs = daily.resolveSongs(byId);
    final label = 'Daily';
    final totalMs = songs.fold<int>(0, (sum, song) => sum + song.durationMs);

    Future<void> refresh() async {
      await daily.refresh(library.songs, styles, profile);
      if (!context.mounted) return;
      showAppSnack(
        context,
        songs.isEmpty && daily.songIds.isEmpty
            ? 'Escolha ao menos um estilo para gerar a Daily.'
            : 'Daily atualizada.',
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Atualizar agora',
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Configurar estilos',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StylesScreen()),
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    scheme.primary,
                    Color.lerp(scheme.primary, const Color(0xFF8B5CF6), 0.7)!,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.today_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Sua seleção de hoje',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    daily.lastGenerated == null
                        ? 'Ainda não gerada'
                        : 'Gerada em ${formatDateTime(daily.lastGeneratedMs)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${songs.length} faixa(s) • ${formatTotalDuration(totalMs)}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: scheme.primary,
                        ),
                        onPressed: songs.isEmpty
                            ? null
                            : () => player.playSongs(songs, label: label),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
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
                                player.playSongs(shuffled, label: label);
                              },
                        icon: const Icon(Icons.shuffle_rounded),
                        color: Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SwitchListTile(
            value: daily.autoUpdate,
            onChanged: (value) async {
              await daily.setAutoUpdate(value);
              if (value) {
                await daily.ensureToday(library.songs, styles, profile);
              }
            },
            secondary: const Icon(Icons.update_rounded),
            title: const Text('Atualizar automaticamente'),
            subtitle: const Text(
              'Uma nova lista por dia. Desligado, ela só muda quando você pedir.',
            ),
          ),
          SectionHeader(
            title: 'Estilos da Daily',
            subtitle: styles.styles.isEmpty
                ? 'Crie estilos para alimentar a Daily'
                : '${daily.styleIds.length} de ${styles.styles.length} selecionado(s)',
            actionLabel: 'Gerenciar',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StylesScreen()),
            ),
          ),
          if (styles.styles.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: EmptyState(
                icon: Icons.palette_outlined,
                title: 'Nenhum estilo ainda',
                message:
                    'A Daily usa apenas os estilos que você criar e marcar aqui. '
                    'Crie um estilo e aplique nas faixas, álbuns ou artistas.',
                compact: true,
                actionLabel: 'Criar estilo',
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const StylesScreen(),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  for (final style in styles.styles)
                    FilterChip(
                      selected: daily.styleIds.contains(style.id),
                      onSelected: (selected) async {
                        final next = <String>{...daily.styleIds};
                        if (selected) {
                          next.add(style.id);
                        } else {
                          next.remove(style.id);
                        }
                        await daily.setStyles(next);
                        await daily.refresh(library.songs, styles, profile);
                        if (context.mounted) {
                          showAppSnack(context, 'Daily atualizada.');
                        }
                      },
                      avatar: CircleAvatar(
                        backgroundColor: Color(style.colorValue),
                        radius: 7,
                      ),
                      label: Text(style.name),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          if (daily.styleIds.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Marque um ou mais estilos acima para montar a Daily.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else if (songs.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: EmptyState(
                icon: Icons.nightlight_round,
                title: 'Daily vazia',
                message:
                    'Nenhuma faixa destes estilos foi encontrada na biblioteca. '
                    'Verifique se os estilos estão aplicados ou toque em atualizar.',
                compact: true,
                actionLabel: 'Atualizar agora',
                onAction: refresh,
              ),
            )
          else
            SectionHeader(
              title: 'Faixas da Daily',
              subtitle: 'A lista salva permanece estável durante o dia',
            ),
          if (songs.isNotEmpty)
            for (final song in songs)
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: scheme.primary.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.music_note_rounded,
                    size: 16,
                    color: scheme.primary,
                  ),
                ),
                title: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  song.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  song.durationLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                onTap: () => player.playSongs(
                  songs,
                  index: songs.indexOf(song),
                  label: label,
                ),
              ),
        ],
      ),
    );
  }
}
