import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils.dart';
import '../../data/daily_controller.dart';
import '../../data/models.dart';
import '../../data/style_controller.dart';
import '../../data/style_models.dart';
import '../../state/app_tab.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../widgets/app_snack.dart';
import '../widgets/common.dart';
import '../widgets/song_tile.dart';
import 'collection_screen.dart';
import 'daily_screen.dart';
import 'mix_screen.dart';
import 'song_list_screen.dart';
import 'styles_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onNavigate,
    required this.onSearch,
  });

  final void Function(AppTab tab) onNavigate;

  /// Abre a busca (que agora vive dentro da Biblioteca).
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final styles = context.watch<StyleController>();
    final player = context.read<PlayerController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final recent = library.collectionSongs(SongCollectionKind.recent, limit: 12);
    final favorites =
        library.collectionSongs(SongCollectionKind.favorites, limit: 12);
    final mostPlayed =
        library.collectionSongs(SongCollectionKind.mostPlayed, limit: 12);
    final recentlyAdded = library.recentlyAdded.take(12).toList();

    final folderCounts = <String, int>{};
    for (final song in library.songs) {
      folderCounts[song.folder] = (folderCounts[song.folder] ?? 0) + 1;
    }
    final folders = folderCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          final ok = await library.scan();
          if (!context.mounted) return;
          showAppSnack(
            context,
            ok
                ? 'Biblioteca atualizada.'
                : (library.error ?? 'Não foi possível atualizar agora.'),
          );
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 4),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          scheme.primary,
                          Color.lerp(scheme.primary, scheme.secondary, 0.6)!,
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.graphic_eq_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'RepSound',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          'Sua música, do seu jeito.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Buscar',
                    onPressed: onSearch,
                    icon: const Icon(Icons.search_rounded),
                  ),
                  IconButton(
                    tooltip: 'Atualizar biblioteca',
                    onPressed: library.isScanning
                        ? null
                        : () async {
                            final ok = await library.scan();
                            if (!context.mounted) return;
                            showAppSnack(
                              context,
                              ok
                                  ? 'Biblioteca atualizada.'
                                  : (library.error ??
                                      'Não foi possível atualizar agora.'),
                            );
                          },
                    icon: library.isScanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            if (library.isScanning)
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 6, 18, 2),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (library.error != null)
              _ErrorBanner(
                message: library.error!,
                actionLabel: library.permissionBlocked ? 'Ajustes' : 'Tentar',
                onRetry: library.permissionBlocked
                    ? () => library.openSystemSettings()
                    : () async {
                        final ok = await library.scan();
                        if (!context.mounted) return;
                        if (ok) showAppSnack(context, 'Biblioteca atualizada.');
                      },
              ),
            if (library.totalSongs == 0)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: EmptyState(
                  icon: Icons.library_music_rounded,
                  title: 'Sua biblioteca está vazia',
                  message: !library.supported
                      ? 'A leitura automática da biblioteca está disponível no Android.'
                      : library.permissionBlocked
                          ? 'O acesso às músicas foi negado. Abra os ajustes do sistema e permita “Música e áudio” para o RepSound.'
                          : 'Escaneie o aparelho para encontrar as músicas do armazenamento interno e do cartão microSD.',
                  actionLabel: library.isScanning
                      ? 'Escaneando...'
                      : library.permissionBlocked
                          ? 'Abrir ajustes'
                          : 'Escanear agora',
                  onAction: library.isScanning
                      ? null
                      : library.permissionBlocked
                          ? () => library.openSystemSettings()
                          : () async {
                              final ok = await library.scan();
                              if (!context.mounted) return;
                              showAppSnack(
                                context,
                                ok
                                    ? '${library.totalSongs} faixas encontradas.'
                                    : (library.error ??
                                        'Nenhuma música encontrada.'),
                              );
                            },
                ),
              )
            else ...<Widget>[
              _LibraryHero(
                totalSongs: library.totalSongs,
                totalArtists: library.totalArtists,
                totalDurationMs: library.totalDurationMs,
                coverSongs: recentlyAdded,
                onPlayAll: () {
                  player.playSongs(
                    library.filteredSongs,
                    label: 'Biblioteca',
                  );
                },
                onShuffle: () {
                  final shuffled = List<Song>.of(library.filteredSongs)
                    ..shuffle();
                  player.playSongs(shuffled, label: 'Biblioteca');
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: StatTile(
                        icon: Icons.music_note_rounded,
                        value: formatCount(library.totalSongs),
                        label: 'músicas',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatTile(
                        icon: Icons.person_rounded,
                        value: formatCount(library.totalArtists),
                        label: 'artistas',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatTile(
                        icon: Icons.album_rounded,
                        value: formatCount(library.totalAlbums),
                        label: 'álbuns',
                      ),
                    ),
                  ],
                ),
              ),
              _CollectionsRow(
                library: library,
                onOpen: (kind) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CollectionScreen(kind: kind),
                  ),
                ),
              ),
              _DailyCard(
                onOpen: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const DailyScreen()),
                ),
              ),
              _RecommendationsRow(
                onFavorites: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MixScreen(kind: MixKind.favorites),
                  ),
                ),
                onDiscoveries: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MixScreen(kind: MixKind.discoveries),
                  ),
                ),
              ),
              if (styles.count > 0)
                _StylesSection(
                  styles: styles,
                  library: library,
                  onManage: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const StylesScreen(),
                    ),
                  ),
                  onOpen: (style) => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StyleSongsScreen(style: style),
                    ),
                  ),
                ),
              if (recent.isNotEmpty)
                _SongStrip(
                  title: 'Ouvidas recentemente',
                  subtitle: 'Continue de onde parou',
                  songs: recent,
                  label: 'Ouvidas recentemente',
                  onSeeAll: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CollectionScreen(
                        kind: SongCollectionKind.recent,
                      ),
                    ),
                  ),
                ),
              if (favorites.isNotEmpty)
                _SongStrip(
                  title: 'Favoritos',
                  subtitle: '${favorites.length} faixa(s) com coração',
                  songs: favorites,
                  label: 'Favoritos',
                  onSeeAll: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CollectionScreen(
                        kind: SongCollectionKind.favorites,
                      ),
                    ),
                  ),
                ),
              if (mostPlayed.isNotEmpty)
                _SongStrip(
                  title: 'Mais ouvidas',
                  subtitle: 'Suas faixas campeãs',
                  songs: mostPlayed,
                  label: 'Mais ouvidas',
                  onSeeAll: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CollectionScreen(
                        kind: SongCollectionKind.mostPlayed,
                      ),
                    ),
                  ),
                ),
              _SongStrip(
                title: 'Adicionadas recentemente',
                subtitle: 'Novidades da biblioteca',
                songs: recentlyAdded,
                label: 'Adicionadas recentemente',
                onSeeAll: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CollectionScreen(
                      kind: SongCollectionKind.recentlyAdded,
                    ),
                  ),
                ),
              ),
              if (folders.isNotEmpty) ...<Widget>[
                SectionHeader(
                  title: 'Pastas',
                  subtitle: '${folders.length} pasta(s) encontradas',
                  actionLabel: 'Biblioteca',
                  onAction: () => onNavigate(AppTab.library),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: <Widget>[
                        for (var index = 0;
                            index < folders.length.clamp(0, 4);
                            index++)
                          _FolderTile(
                            folder: folders[index].key,
                            count: folders[index].value,
                            showDivider: index < folders.length.clamp(0, 4) - 1,
                            onTap: () {
                              final songs = library.songs
                                  .where(
                                    (song) =>
                                        song.folder == folders[index].key,
                                  )
                                  .toList();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => SongListScreen(
                                    title: folders[index].key,
                                    subtitle: 'Pasta',
                                    songs: songs,
                                    queueLabel: folders[index].key,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final daily = context.watch<DailyController>();
    final library = context.watch<LibraryController>();
    final player = context.read<PlayerController>();
    final songs = daily.resolveSongs(library.songById);
    final configured = daily.styleIds.isNotEmpty;
    final generated = daily.lastGeneratedMs > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Daily',
          subtitle: generated
              ? '${songs.length} faixa(s) • ${formatDateTime(daily.lastGeneratedMs)}'
              : 'Sua seleção do dia',
          actionLabel: 'Abrir',
          onAction: onOpen,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Material(
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onOpen,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      scheme.primary,
                      Color.lerp(scheme.primary, const Color(0xFF8B5CF6), 0.75)!,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.today_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              configured
                                  ? 'Sua seleção de hoje'
                                  : 'Escolha estilos para a Daily',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              configured
                                  ? (songs.isEmpty
                                      ? 'Toque para gerar ou revisar os estilos'
                                      : '${songs.length} faixa(s) • mistura do dia')
                                  : 'A Daily mistura favoritas e descobertas dos seus estilos.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tocar Daily',
                        onPressed: songs.isEmpty
                            ? onOpen
                            : () => player.playSongs(songs, label: 'Daily'),
                        icon: Icon(
                          songs.isEmpty
                              ? Icons.chevron_right_rounded
                              : Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecommendationsRow extends StatelessWidget {
  const _RecommendationsRow({
    required this.onFavorites,
    required this.onDiscoveries,
  });

  final VoidCallback onFavorites;
  final VoidCallback onDiscoveries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cards = <_MixShortcut>[
      _MixShortcut(
        title: 'Mix Favoritas',
        subtitle: 'Pelas suas favoritas e artistas',
        icon: Icons.favorite_rounded,
        color: scheme.primary,
        onTap: onFavorites,
      ),
      _MixShortcut(
        title: 'Descobertas',
        subtitle: 'Metade de faixas nunca ouvidas',
        icon: Icons.explore_rounded,
        color: const Color(0xFF10B981),
        onTap: onDiscoveries,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'Recomendadas para você',
          subtitle: 'Sorteio ponderado — sempre diferente',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              for (var index = 0; index < cards.length; index++) ...<Widget>[
                if (index > 0) const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    color: theme.brightness == Brightness.dark
                        ? scheme.surfaceContainerLow
                        : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: cards[index].onTap,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: cards[index]
                                    .color
                                    .withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                cards[index].icon,
                                color: cards[index].color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              cards[index].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              cards[index].subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MixShortcut {
  const _MixShortcut({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _StylesSection extends StatelessWidget {
  const _StylesSection({
    required this.styles,
    required this.library,
    required this.onManage,
    required this.onOpen,
  });

  final StyleController styles;
  final LibraryController library;
  final VoidCallback onManage;
  final void Function(SongStyle style) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = <SongStyle>[
      for (final style in styles.styles)
        if (styles.songsWithStyle(library.songs, style.id).isNotEmpty) style,
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Playlists por estilo',
          subtitle: '${items.length} estilo(s) com faixas',
          actionLabel: 'Gerenciar',
          onAction: onManage,
        ),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final style = items[index];
              final color = Color(style.colorValue);
              final count =
                  styles.songsWithStyle(library.songs, style.id).length;
              return SizedBox(
                width: 168,
                child: Material(
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onOpen(style),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            color.withValues(alpha: 0.85),
                            Color.lerp(color, scheme.surface, 0.55)!,
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Icon(
                              Icons.palette_rounded,
                              color: Colors.white.withValues(alpha: 0.9),
                              size: 22,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  style.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '$count faixa(s)',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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
}

class _LibraryHero extends StatelessWidget {
  const _LibraryHero({
    required this.totalSongs,
    required this.totalArtists,
    required this.totalDurationMs,
    required this.coverSongs,
    required this.onPlayAll,
    required this.onShuffle,
  });

  final int totalSongs;
  final int totalArtists;
  final int totalDurationMs;
  final List<Song> coverSongs;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              scheme.primary,
              Color.lerp(scheme.primary, scheme.secondary, 0.55)!,
              Color.lerp(scheme.primary, const Color(0xFF8B5CF6), 0.75)!,
            ],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.30),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'TOCAR TUDO',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$totalSongs músicas',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$totalArtists artistas • ${formatTotalDuration(totalDurationMs)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: scheme.primary,
                          minimumSize: const Size(0, 40),
                        ),
                        onPressed: onPlayAll,
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('Tocar'),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Aleatório',
                        onPressed: onShuffle,
                        icon: const Icon(Icons.shuffle_rounded),
                        color: Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            CollectionCover(
              songs: coverSongs,
              size: 104,
              radius: 20,
              icon: Icons.library_music_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionsRow extends StatelessWidget {
  const _CollectionsRow({required this.library, required this.onOpen});

  final LibraryController library;
  final void Function(SongCollectionKind kind) onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = <_CollectionShortcut>[
      _CollectionShortcut(
        kind: SongCollectionKind.favorites,
        label: 'Favoritos',
        icon: Icons.favorite_rounded,
        color: scheme.primary,
      ),
      _CollectionShortcut(
        kind: SongCollectionKind.recent,
        label: 'Ouvidas recentes',
        icon: Icons.history_rounded,
        color: const Color(0xFF22D3EE),
      ),
      _CollectionShortcut(
        kind: SongCollectionKind.mostPlayed,
        label: 'Mais ouvidas',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF10B981),
      ),
      _CollectionShortcut(
        kind: SongCollectionKind.recentlyAdded,
        label: 'Novidades',
        icon: Icons.new_releases_rounded,
        color: const Color(0xFFF59E0B),
      ),
    ];

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          final count = library.collectionCount(item.kind);
          return SizedBox(
            width: 166,
            child: Material(
              color: Theme.of(context).brightness == Brightness.dark
                  ? scheme.surfaceContainerLow
                  : Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onOpen(item.kind),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.icon, size: 20, color: item.color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$count faixa(s)',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
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

class _CollectionShortcut {
  const _CollectionShortcut({
    required this.kind,
    required this.label,
    required this.icon,
    required this.color,
  });

  final SongCollectionKind kind;

  /// Rótulo curto usado no cartão (os nomes completos aparecem nas telas).
  final String label;
  final IconData icon;
  final Color color;
}

class _SongStrip extends StatelessWidget {
  const _SongStrip({
    required this.title,
    required this.subtitle,
    required this.songs,
    required this.label,
    required this.onSeeAll,
  });

  final String title;
  final String subtitle;
  final List<Song> songs;
  final String label;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) return const SizedBox.shrink();
    final player = context.read<PlayerController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: title,
          subtitle: subtitle,
          actionLabel: 'Ver tudo',
          onAction: onSeeAll,
        ),
        SizedBox(
          height: 218,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: songs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final song = songs[index];
              return SizedBox(
                width: 140,
                child: SongGridCard(
                  song: song,
                  queue: songs,
                  queueLabel: label,
                  onTap: () => player.playSongs(
                    songs,
                    index: index,
                    label: label,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.folder,
    required this.count,
    required this.onTap,
    this.showDivider = true,
  });

  final String folder;
  final int count;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        ListTile(
          onTap: onTap,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.folder_rounded, color: scheme.primary, size: 21),
          ),
          title: Text(
            folder,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '$count faixa(s)',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
        if (showDivider)
          Divider(height: 1, indent: 68, color: scheme.outlineVariant),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onRetry,
    this.actionLabel = 'Tentar',
  });

  final String message;
  final VoidCallback onRetry;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.error.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline_rounded, color: scheme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
