import 'dart:math' as math;

import '../core/utils.dart';
import 'models.dart';
import 'playlist_controller.dart';

/// Recomendações com sorteio ponderado (ninguém tem certeza de aparecer).
///
/// As proporções ficam em constantes para facilitar ajustes.
class RecommendationService {
  RecommendationService._();

  /// Descobertas: 50% nunca ouvidas, 30% já ouvidas de artistas favoritos,
  /// 20% antigas aleatórias.
  static const double discoveryNewShare = 0.50;
  static const double discoveryKnownShare = 0.30;
  static const double discoveryOldShare = 0.20;

  /// Evita mais de 2 faixas seguidas do mesmo artista.
  static const int maxConsecutiveArtist = 2;

  static const int defaultLimit = 40;

  static List<Song> mixFavorites(
    List<Song> songs,
    PlaylistController profile, {
    int limit = defaultLimit,
    math.Random? random,
  }) {
    if (songs.isEmpty) return const <Song>[];
    final topArtists = _topArtists(songs, profile, 10);
    final weights = <String, double>{};
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final song in songs) {
      final plays = profile.playCountFor(song.id);
      final last = profile.lastPlayedFor(song.id);
      final skips = profile.skipCountFor(song.id);
      var weight = 1.0 + plays * 2.2;
      if (profile.isFavorite(song.id)) weight += 5;
      if (last > 0) {
        final days = (now - last) / Duration.millisecondsPerDay;
        if (days <= 7) {
          weight *= 2.4;
        } else if (days <= 30) {
          weight *= 1.5;
        } else if (days > 180) {
          weight *= 0.75;
        }
      }
      if (topArtists.contains(normalizeForSearch(song.artist))) {
        weight += plays > 0 ? 1.5 : 0.8;
      }
      weight /= 1 + skips * 1.6;
      final listened = profile.averageListenedFor(song.id);
      if (listened > 0) weight *= 0.5 + listened;
      weights[song.id] = math.max(weight, 0.05);
    }
    return _spread(
      _weightedPick(songs, limit, weights, random ?? math.Random()),
    );
  }

  static List<Song> discoveries(
    List<Song> songs,
    PlaylistController profile, {
    int limit = defaultLimit,
    math.Random? random,
  }) {
    if (songs.isEmpty) return const <Song>[];
    final rng = random ?? math.Random();
    final now = DateTime.now().millisecondsSinceEpoch;
    final topArtists = _topArtists(songs, profile, 12);

    final unplayed = <Song>[];
    final known = <Song>[];
    final all = List<Song>.of(songs);
    for (final song in songs) {
      final plays = profile.playCountFor(song.id);
      if (plays == 0) {
        unplayed.add(song);
      } else if (topArtists.contains(normalizeForSearch(song.artist))) {
        known.add(song);
      }
    }

    // Fallback para app novo: recentes + aleatórias.
    if (unplayed.length == songs.length && known.isEmpty) {
      final recent = List<Song>.of(all)
        ..sort((a, b) => b.dateAddedMs.compareTo(a.dateAddedMs));
      final fresh = recent.take((limit * 0.4).round()).toList();
      final rest = all.where((song) => !fresh.contains(song)).toList()
        ..shuffle(rng);
      return _spread(<Song>[...fresh, ...rest.take(limit - fresh.length)]);
    }

    final recentLimit = now - 90 * Duration.millisecondsPerDay;
    final weightsUnplayed = <String, double>{
      for (final song in unplayed)
        song.id: 1.0 +
            (song.dateAddedMs >= recentLimit ? 2.2 : 0) +
            (topArtists.contains(normalizeForSearch(song.artist)) ? 2.5 : 0),
    };
    final weightsKnown = <String, double>{
      for (final song in known)
        song.id: 1.0 +
            profile.playCountFor(song.id) * 0.6 +
            (profile.isFavorite(song.id) ? 1.5 : 0),
    };

    final wasOld = <String, double>{};
    if (all.length > 20) {
      final dates = all.map((song) => song.dateAddedMs).toList()..sort();
      final median = dates[dates.length ~/ 2];
      for (final song in all) {
        if (song.dateAddedMs <= median) wasOld[song.id] = 1;
      }
    }

    final result = <Song>[];
    void take(Map<String, double> weights, double share) {
      final count = (limit * share).round();
      final pool = <Song>[
        for (final song in all)
          if (weights[song.id] != null) song,
      ];
      result.addAll(_weightedPick(pool, count, weights, rng));
    }

    take(weightsUnplayed, discoveryNewShare);
    take(weightsKnown, discoveryKnownShare);
    take(wasOld, discoveryOldShare);

    if (result.length < limit) {
      final remaining = <Song>[
        for (final song in all)
          if (!result.any((picked) => picked.id == song.id)) song,
      ]..shuffle(rng);
      result.addAll(remaining.take(limit - result.length));
    }
    return _spread(result);
  }

  /// Daily: mais ouvidas + artistas favoritos, restrito aos estilos.
  static List<Song> daily(
    List<Song> songs,
    PlaylistController profile, {
    int limit = defaultLimit,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final favoriteMix = mixFavorites(songs, profile, limit: limit, random: rng);
    if (favoriteMix.length >= limit) return favoriteMix;
    final discovery = discoveries(songs, profile, limit: limit, random: rng);
    final seen = <String>{for (final song in favoriteMix) song.id};
    return _spread(<Song>[
      ...favoriteMix,
      for (final song in discovery)
        if (seen.add(song.id)) song,
    ]).take(limit).toList();
  }

  /// Playlist automática de um estilo (lógica de Descobertas).
  static List<Song> styleMix(
    List<Song> songs,
    PlaylistController profile, {
    int limit = defaultLimit,
    math.Random? random,
  }) =>
      discoveries(songs, profile, limit: limit, random: random);

  // ------------------------------------------------------------------ utils

  static Set<String> _topArtists(
    List<Song> songs,
    PlaylistController profile,
    int count,
  ) {
    final totals = <String, int>{};
    for (final song in songs) {
      final plays = profile.playCountFor(song.id);
      if (plays > 0) {
        final key = normalizeForSearch(song.artist);
        totals[key] = (totals[key] ?? 0) + plays;
      }
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return <String>{for (final entry in sorted.take(count)) entry.key};
  }

  static List<Song> _weightedPick(
    List<Song> pool,
    int count,
    Map<String, double> weights,
    math.Random random,
  ) {
    final remaining = <Song>[
      for (final song in pool)
        if ((weights[song.id] ?? 0) > 0) song,
    ];
    final picked = <Song>[];
    final recentArtists = <String>[];
    var total = remaining.fold<double>(
      0,
      (sum, song) => sum + (weights[song.id] ?? 0),
    );
    while (picked.length < count && remaining.isNotEmpty && total > 0) {
      final blocked = recentArtists.length >= maxConsecutiveArtist &&
          recentArtists
                  .skip(recentArtists.length - maxConsecutiveArtist)
                  .toSet()
                  .length ==
              1
          ? recentArtists.last
          : null;

      var target = random.nextDouble() * total;
      Song? selected;
      var selectedIndex = 0;
      for (var index = 0; index < remaining.length; index++) {
        final song = remaining[index];
        if (blocked != null &&
            normalizeForSearch(song.artist) == blocked &&
            remaining.length > 1) {
          continue;
        }
        target -= weights[song.id] ?? 0;
        if (target <= 0) {
          selected = song;
          selectedIndex = index;
          break;
        }
      }
      if (selected == null) {
        selectedIndex = remaining.length - 1;
        selected = remaining[selectedIndex];
      }
      picked.add(selected);
      remaining.removeAt(selectedIndex);
      total -= weights[selected.id] ?? 0;
      recentArtists.add(normalizeForSearch(selected.artist));
    }
    return picked;
  }

  /// Reorganiza para não repetir o mesmo artista mais de 2 vezes seguidas.
  static List<Song> _spread(List<Song> songs) {
    final result = <Song>[];
    final pool = List<Song>.of(songs);
    while (pool.isNotEmpty) {
      String? blocked;
      if (result.length >= maxConsecutiveArtist) {
        final tail = result
            .skip(result.length - maxConsecutiveArtist)
            .map((song) => normalizeForSearch(song.artist))
            .toSet();
        if (tail.length == 1) blocked = tail.first;
      }
      var index = 0;
      if (blocked != null) {
        final found = pool.indexWhere(
          (song) => normalizeForSearch(song.artist) != blocked,
        );
        if (found >= 0) index = found;
      }
      result.add(pool.removeAt(index));
    }
    return result;
  }
}
