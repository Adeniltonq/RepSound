import '../core/utils.dart';
import 'models.dart';

/// Busca instantânea sobre o índice leve em memória.
///
/// Cada música já tem seus campos normalizados (`titleKey`, `artistKey`...),
/// então a busca é apenas substring + pontuação, sem alocar strings por faixa.
abstract final class SearchService {
  static List<Song> search(
    List<Song> songs,
    String query,
    SearchField field, {
    int limit = 500,
  }) {
    final normalized = normalizeForSearch(query);
    if (normalized.isEmpty) return const <Song>[];
    final tokens = normalized.split(' ').where((token) => token.isNotEmpty);
    if (tokens.isEmpty) return const <Song>[];

    final hits = <_ScoredSong>[];
    for (final song in songs) {
      final haystack = switch (field) {
        SearchField.all => song.searchKey,
        SearchField.title => song.titleKey,
        SearchField.artist => song.artistKey,
        SearchField.album => song.albumKey,
        SearchField.folder => song.folderKey,
      };
      var matches = true;
      for (final token in tokens) {
        if (!haystack.contains(token)) {
          matches = false;
          break;
        }
      }
      if (!matches) continue;
      hits.add(_ScoredSong(song, _score(song, normalized, field)));
    }

    hits.sort((a, b) {
      final byScore = a.score.compareTo(b.score);
      if (byScore != 0) return byScore;
      final byTitle = a.song.titleKey.compareTo(b.song.titleKey);
      if (byTitle != 0) return byTitle;
      return a.song.artistKey.compareTo(b.song.artistKey);
    });

    if (hits.length > limit) {
      return hits.take(limit).map((hit) => hit.song).toList(growable: false);
    }
    return hits.map((hit) => hit.song).toList(growable: false);
  }

  static int _score(Song song, String query, SearchField field) {
    final title = song.titleKey;
    final artist = song.artistKey;
    final album = song.albumKey;
    final folder = song.folderKey;

    switch (field) {
      case SearchField.title:
        if (title == query) return 0;
        if (title.startsWith(query)) return 1;
        return 2;
      case SearchField.artist:
        if (artist == query) return 0;
        if (artist.startsWith(query)) return 1;
        return 2;
      case SearchField.album:
        if (album == query) return 0;
        if (album.startsWith(query)) return 1;
        return 2;
      case SearchField.folder:
        if (folder == query) return 0;
        if (folder.startsWith(query)) return 1;
        return 2;
      case SearchField.all:
        if (title == query) return 0;
        if (title.startsWith(query)) return 1;
        if (title.contains(query)) return 2;
        if (artist == query) return 3;
        if (artist.startsWith(query)) return 4;
        if (artist.contains(query)) return 5;
        if (album.startsWith(query)) return 6;
        if (album.contains(query)) return 7;
        if (folder.contains(query)) return 8;
        return 9;
    }
  }
}

class _ScoredSong {
  const _ScoredSong(this.song, this.score);

  final Song song;
  final int score;
}
