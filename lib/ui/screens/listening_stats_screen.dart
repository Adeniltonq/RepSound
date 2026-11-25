import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils.dart';
import '../../data/models.dart';
import '../../data/playlist_controller.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../widgets/common.dart';
import '../widgets/song_artwork.dart';

/// Histórico de reprodução, pulos e percentual médio ouvido.
class ListeningStatsScreen extends StatelessWidget {
  const ListeningStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = context.watch<PlaylistController>();
    final library = context.watch<LibraryController>();
    final player = context.read<PlayerController>();

    final playCounts = profile.playCounts;
    final skipCounts = profile.skipCounts;
    final totalPlays = playCounts.values.fold<int>(0, (a, b) => a + b);
    final totalSkips = skipCounts.values.fold<int>(0, (a, b) => a + b);
    final listenedSum =
        profile.listenedSamples.keys.fold<double>(0, (sum, id) {
      final samples = profile.listenedSamples[id] ?? 0;
      return sum + profile.averageListenedFor(id) * samples;
    });
    final listenedSamples =
        profile.listenedSamples.values.fold<int>(0, (a, b) => a + b);
    final average = listenedSamples > 0 ? listenedSum / listenedSamples : 0.0;

    final lastSong = _lastPlayed(profile, library);
    final history = <Song>[
      for (final id in profile.history)
        if (library.songById[id] != null) library.songById[id]!,
    ];
    final topPlayed = _top(playCounts, library, totalPlays, limit: 20);
    final topSkipped = _top(skipCounts, library, totalSkips, limit: 20);

    return Scaffold(
      appBar: AppBar(title: const Text('Estatísticas de escuta')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: StatTile(
                        icon: Icons.play_arrow_rounded,
                        value: formatCount(totalPlays),
                        label: 'reproduções',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatTile(
                        icon: Icons.skip_next_rounded,
                        value: formatCount(totalSkips),
                        label: 'pulos',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: StatTile(
                        icon: Icons.hearing_rounded,
                        value:
                            listenedSamples == 0
                                ? '—'
                                : '${(average * 100).round()}%',
                        label: 'média ouvida',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatTile(
                        icon: Icons.music_note_rounded,
                        value: formatCount(
                          playCounts.values.where((v) => v > 0).length,
                        ),
                        label: 'faixas ouvidas',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (lastSong != null) ...<Widget>[
            const SectionHeader(
              title: 'Última reprodução',
              subtitle: 'Onde você parou pela última vez',
            ),
            _StatSongTile(
              song: lastSong,
              trailing: formatRelativeDay(
                profile.lastPlayedFor(lastSong.id),
              ),
              onTap: () => player.playSongs(
                <Song>[lastSong],
                label: 'Última reprodução',
              ),
            ),
          ],
          if (history.isNotEmpty) ...<Widget>[
            SectionHeader(
              title: 'Histórico recente',
              subtitle: '${history.length} faixa(s)',
            ),
            for (final song in history.take(40))
              _StatSongTile(
                song: song,
                trailing: formatRelativeDay(
                  profile.lastPlayedFor(song.id),
                ),
                subtitle:
                    'Reproduções: ${profile.playCountFor(song.id)} • '
                    'Pulos: ${profile.skipCountFor(song.id)} • '
                    'Ouvida: ${(profile.averageListenedFor(song.id) * 100).round()}%',
                onTap: () => player.playSongs(
                  history,
                  index: history.indexOf(song),
                  label: 'Histórico',
                ),
              ),
          ],
          if (topPlayed.isNotEmpty) ...<Widget>[
            const SectionHeader(
              title: 'Mais reproduzidas',
              subtitle: 'Contagem desde o último reset',
            ),
            for (final entry in topPlayed)
              _StatSongTile(
                song: entry.key,
                trailing: '${entry.value}x',
                subtitle:
                    'Pulos: ${profile.skipCountFor(entry.key.id)} • '
                    'Ouvida: ${(profile.averageListenedFor(entry.key.id) * 100).round()}%',
                onTap: () => player.playSongs(
                  <Song>[entry.key],
                  label: 'Mais reproduzidas',
                ),
              ),
          ],
          if (topSkipped.isNotEmpty) ...<Widget>[
            const SectionHeader(
              title: 'Mais puladas',
              subtitle: 'Faixas que você costuma passar',
            ),
            for (final entry in topSkipped)
              _StatSongTile(
                song: entry.key,
                trailing: '${entry.value} pulo(s)',
                onTap: () => player.playSongs(
                  <Song>[entry.key],
                  label: 'Mais puladas',
                ),
              ),
          ],
          if (history.isEmpty && topPlayed.isEmpty)
            const EmptyState(
              icon: Icons.insights_rounded,
              title: 'Sem dados ainda',
              message:
                  'Ouça faixas por pelo menos ~30 segundos (ou ~50% da duração) '
                  'para o RepSound registrar reproduções, pulos e tempo ouvido.',
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Text(
              'Reprodução válida: mais de ~30 s ou ~50% da faixa. '
              'O percentual ouvido é a média das últimas execuções.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Song? _lastPlayed(
    PlaylistController profile,
    LibraryController library,
  ) {
    Song? result;
    var best = 0;
    profile.lastPlayed.forEach((id, time) {
      if (time > best && library.songById[id] != null) {
        best = time;
        result = library.songById[id];
      }
    });
    return result;
  }

  static List<MapEntry<Song, int>> _top(
    Map<String, int> counts,
    LibraryController library,
    int total, {
    required int limit,
  }) {
    final entries = <MapEntry<Song, int>>[
      for (final entry in counts.entries)
        if (entry.value > 0 && library.songById[entry.key] != null)
          MapEntry<Song, int>(library.songById[entry.key]!, entry.value),
    ];
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }
}

class _StatSongTile extends StatelessWidget {
  const _StatSongTile({
    required this.song,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final Song song;
  final VoidCallback onTap;
  final String? subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: SongArtwork(song: song, size: 42, radius: 10),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle ?? song.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      trailing: trailing == null
          ? null
          : Text(
              trailing!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
    );
  }
}
