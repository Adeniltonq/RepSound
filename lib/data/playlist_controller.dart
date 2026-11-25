import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/utils.dart';
import 'models.dart';
import 'profile_store.dart';

/// Playlists, favoritos e estatísticas de escuta.
class PlaylistController extends ChangeNotifier {
  PlaylistController(this._store);

  final ProfileStore _store;
  final Debouncer _saveDebouncer = Debouncer(delay: const Duration(milliseconds: 450));

  List<Playlist> _playlists = <Playlist>[];
  List<String> _favorites = <String>[];
  Map<String, int> _playCounts = <String, int>{};
  Map<String, int> _lastPlayed = <String, int>{};
  Map<String, int> _skipCounts = <String, int>{};
  Map<String, double> _listenedSum = <String, double>{};
  Map<String, int> _listenedSamples = <String, int>{};
  List<String> _history = <String>[];

  bool _loaded = false;
  bool get isLoaded => _loaded;

  List<Playlist> get playlists => UnmodifiableListView<Playlist>(_playlists);
  List<String> get favorites => UnmodifiableListView<String>(_favorites);
  Map<String, int> get playCounts => UnmodifiableMapView<String, int>(_playCounts);
  Map<String, int> get lastPlayed => UnmodifiableMapView<String, int>(_lastPlayed);
  Map<String, int> get skipCounts => UnmodifiableMapView<String, int>(_skipCounts);
  List<String> get history => UnmodifiableListView<String>(_history);

  Map<String, double> get listenedSum =>
      UnmodifiableMapView<String, double>(_listenedSum);
  Map<String, int> get listenedSamples =>
      UnmodifiableMapView<String, int>(_listenedSamples);
  int get favoriteCount => _favorites.length;
  int get playlistCount => _playlists.length;

  Future<void> load() async {
    final data = await _store.load();
    if (data != null) {
      _applyRawProfile(data);
    }
    _loaded = true;
    notifyListeners();
  }

  void _applyRawProfile(Map<String, dynamic> data) {
    final rawPlaylists = data['playlists'];
    if (rawPlaylists is List) {
      _playlists = rawPlaylists
          .whereType<Map>()
          .map((entry) => Playlist.fromJson(Map<String, dynamic>.from(entry)))
          .toList();
    }

    final rawFavorites = data['favorites'];
    if (rawFavorites is List) {
      _favorites = <String>{
        ...rawFavorites.map((entry) => entry.toString()),
      }.toList();
    }

    final stats = data['stats'];
    if (stats is Map) {
      final counts = stats['playCounts'];
      if (counts is Map) {
        _playCounts = <String, int>{};
        counts.forEach((key, value) {
          if (value is num) _playCounts[key.toString()] = value.toInt();
        });
      }
      final lastPlayed = stats['lastPlayed'];
      if (lastPlayed is Map) {
        _lastPlayed = <String, int>{};
        lastPlayed.forEach((key, value) {
          if (value is num) _lastPlayed[key.toString()] = value.toInt();
        });
      }
      final history = stats['history'];
      if (history is List) {
        _history = <String>{
          ...history.map((entry) => entry.toString()),
        }.toList();
      }
      final skips = stats['skipCounts'];
      if (skips is Map) {
        _skipCounts = <String, int>{};
        skips.forEach((key, value) {
          if (value is num) _skipCounts[key.toString()] = value.toInt();
        });
      }
      final listenedSum = stats['listenedSum'];
      if (listenedSum is Map) {
        _listenedSum = <String, double>{};
        listenedSum.forEach((key, value) {
          if (value is num) _listenedSum[key.toString()] = value.toDouble();
        });
      }
      final listenedSamples = stats['listenedSamples'];
      if (listenedSamples is Map) {
        _listenedSamples = <String, int>{};
        listenedSamples.forEach((key, value) {
          if (value is num) _listenedSamples[key.toString()] = value.toInt();
        });
      }
    }
  }

  // ------------------------------------------------------------- playlists

  Playlist? playlistById(String id) {
    for (final playlist in _playlists) {
      if (playlist.id == id) return playlist;
    }
    return null;
  }

  Playlist createPlaylist(String name) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cleanName = name.trim().isEmpty ? 'Nova playlist' : name.trim();
    final playlist = Playlist(
      id: 'pl_${DateTime.now().microsecondsSinceEpoch}',
      name: cleanName,
      songIds: const <String>[],
      createdAtMs: now,
      updatedAtMs: now,
    );
    _playlists.insert(0, playlist);
    notifyListeners();
    _scheduleSave();
    return playlist;
  }

  void renamePlaylist(String id, String name) {
    final index = _playlists.indexWhere((playlist) => playlist.id == id);
    if (index < 0) return;
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    _playlists[index] = _playlists[index].copyWith(
      name: cleanName,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
    _scheduleSave();
  }

  void deletePlaylist(String id) {
    _playlists.removeWhere((playlist) => playlist.id == id);
    notifyListeners();
    _scheduleSave();
  }

  int addSongs(String playlistId, Iterable<Song> songs) {
    final index = _playlists.indexWhere((playlist) => playlist.id == playlistId);
    if (index < 0) return 0;
    final playlist = _playlists[index];
    final existing = playlist.songIds.toSet();
    var added = 0;
    for (final song in songs) {
      if (existing.add(song.id)) added++;
    }
    if (added == 0) return 0;
    _playlists[index] = playlist.copyWith(
      songIds: existing.toList(),
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
    _scheduleSave();
    return added;
  }

  void removeSongFromPlaylist(String playlistId, String songId) {
    final index = _playlists.indexWhere((playlist) => playlist.id == playlistId);
    if (index < 0) return;
    final playlist = _playlists[index];
    final updated = List<String>.of(playlist.songIds)..remove(songId);
    if (updated.length == playlist.songIds.length) return;
    _playlists[index] = playlist.copyWith(
      songIds: updated,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
    _scheduleSave();
  }

  void reorderPlaylist(String playlistId, int oldIndex, int newIndex) {
    final index = _playlists.indexWhere((playlist) => playlist.id == playlistId);
    if (index < 0) return;
    final playlist = _playlists[index];
    if (oldIndex < 0 || oldIndex >= playlist.songIds.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0) target = 0;
    if (target >= playlist.songIds.length) {
      target = playlist.songIds.length - 1;
    }
    final ids = List<String>.of(playlist.songIds);
    final moved = ids.removeAt(oldIndex);
    ids.insert(target, moved);
    _playlists[index] = playlist.copyWith(
      songIds: ids,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
    _scheduleSave();
  }

  /// Move uma faixa usando índices já ajustados (API `onReorderItem`).
  void movePlaylistSong(String playlistId, int oldIndex, int newIndex) {
    final index = _playlists.indexWhere((playlist) => playlist.id == playlistId);
    if (index < 0) return;
    final playlist = _playlists[index];
    final ids = List<String>.of(playlist.songIds);
    if (oldIndex < 0 || oldIndex >= ids.length) return;
    final target = newIndex.clamp(0, ids.length - 1).toInt();
    final moved = ids.removeAt(oldIndex);
    ids.insert(target, moved);
    _playlists[index] = playlist.copyWith(
      songIds: ids,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
    _scheduleSave();
  }

  // ------------------------------------------------------------- favorites

  bool isFavorite(String songId) => _favorites.contains(songId);

  bool toggleFavorite(Song song) {
    final index = _favorites.indexOf(song.id);
    final nowFavorite = index < 0;
    if (nowFavorite) {
      _favorites.insert(0, song.id);
    } else {
      _favorites.removeAt(index);
    }
    notifyListeners();
    _scheduleSave();
    return nowFavorite;
  }

  void removeFavorite(String songId) {
    if (_favorites.remove(songId)) {
      notifyListeners();
      _scheduleSave();
    }
  }

  // ----------------------------------------------------------------- stats

  int playCountFor(String songId) => _playCounts[songId] ?? 0;

  int lastPlayedFor(String songId) => _lastPlayed[songId] ?? 0;

  void recordPlayStart(Song song) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _history.remove(song.id);
    _history.insert(0, song.id);
    if (_history.length > 200) {
      _history.removeRange(200, _history.length);
    }
    _lastPlayed[song.id] = now;
    notifyListeners();
    _scheduleSave();
  }

  void recordListen(Song song) {
    _playCounts[song.id] = (_playCounts[song.id] ?? 0) + 1;
    notifyListeners();
    _scheduleSave();
  }

  /// Faixa pulada antes de atingir o tempo mínimo de escuta.
  void recordSkip(Song song) {
    _skipCounts[song.id] = (_skipCounts[song.id] ?? 0) + 1;
    notifyListeners();
    _scheduleSave();
  }

  /// Percentual ouvido da faixa (0..1), acumulado para a média.
  void recordListened(Song song, double ratio) {
    final clamped = ratio.clamp(0.0, 1.0).toDouble();
    _listenedSum[song.id] = (_listenedSum[song.id] ?? 0) + clamped;
    _listenedSamples[song.id] = (_listenedSamples[song.id] ?? 0) + 1;
    notifyListeners();
    _scheduleSave();
  }

  int skipCountFor(String songId) => _skipCounts[songId] ?? 0;

  double averageListenedFor(String songId) {
    final samples = _listenedSamples[songId] ?? 0;
    if (samples == 0) return 0;
    return (_listenedSum[songId] ?? 0) / samples;
  }

  void clearHistory() {
    _history = <String>[];
    notifyListeners();
    _scheduleSave();
  }

  /// Remove referências a faixas excluídas do aparelho.
  void purgeSongs(Set<String> ids) {
    if (ids.isEmpty) return;
    _favorites.removeWhere(ids.contains);
    _history.removeWhere(ids.contains);
    _playCounts.removeWhere((key, _) => ids.contains(key));
    _lastPlayed.removeWhere((key, _) => ids.contains(key));
    _skipCounts.removeWhere((key, _) => ids.contains(key));
    _listenedSum.removeWhere((key, _) => ids.contains(key));
    _listenedSamples.removeWhere((key, _) => ids.contains(key));
    for (var index = 0; index < _playlists.length; index++) {
      final playlist = _playlists[index];
      final remaining = <String>[
        for (final id in playlist.songIds)
          if (!ids.contains(id)) id,
      ];
      if (remaining.length != playlist.songIds.length) {
        _playlists[index] = playlist.copyWith(
          songIds: remaining,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        );
      }
    }
    notifyListeners();
    _scheduleSave();
  }

  void resetStatistics() {
    _playCounts = <String, int>{};
    _lastPlayed = <String, int>{};
    _skipCounts = <String, int>{};
    _listenedSum = <String, double>{};
    _listenedSamples = <String, int>{};
    _history = <String>[];
    notifyListeners();
    _scheduleSave();
  }

  // --------------------------------------------------------------- persist

  Map<String, dynamic> toProfileJson() => <String, dynamic>{
        'app': 'RepSound',
        'version': 1,
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        'playlists': _playlists.map((playlist) => playlist.toJson()).toList(),
        'favorites': List<String>.of(_favorites),
        'stats': <String, dynamic>{
          'playCounts': Map<String, int>.of(_playCounts),
          'lastPlayed': Map<String, int>.of(_lastPlayed),
          'skipCounts': Map<String, int>.of(_skipCounts),
          'listenedSum': Map<String, double>.of(_listenedSum),
          'listenedSamples': Map<String, int>.of(_listenedSamples),
          'history': List<String>.of(_history),
        },
      };

  Future<void> importData({
    required List<Playlist> playlists,
    required List<String> favorites,
    required Map<String, int> playCounts,
    required Map<String, int> lastPlayed,
    required List<String> history,
    Map<String, int> skipCounts = const <String, int>{},
    Map<String, double> listenedSum = const <String, double>{},
    Map<String, int> listenedSamples = const <String, int>{},
    required bool merge,
  }) async {
    if (merge) {
      for (final incoming in playlists) {
        final incomingKey = normalizeForSearch(incoming.name);
        final index = _playlists.indexWhere(
          (existing) => normalizeForSearch(existing.name) == incomingKey,
        );
        if (index >= 0) {
          final existing = _playlists[index];
          final ids = <String>{...existing.songIds, ...incoming.songIds}.toList();
          _playlists[index] = existing.copyWith(
            songIds: ids,
            updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          );
        } else {
          _playlists.add(incoming);
        }
      }
      for (final id in favorites) {
        if (!_favorites.contains(id)) _favorites.add(id);
      }
      playCounts.forEach((id, count) {
        _playCounts[id] = (_playCounts[id] ?? 0) + count;
      });
      lastPlayed.forEach((id, time) {
        _lastPlayed[id] = math.max(_lastPlayed[id] ?? 0, time);
      });
      _history = <String>{...history, ..._history}.take(200).toList();
      skipCounts.forEach((id, count) {
        _skipCounts[id] = (_skipCounts[id] ?? 0) + count;
      });
      listenedSum.forEach((id, sum) {
        _listenedSum[id] = (_listenedSum[id] ?? 0) + sum;
      });
      listenedSamples.forEach((id, samples) {
        _listenedSamples[id] = (_listenedSamples[id] ?? 0) + samples;
      });
    } else {
      _playlists = List<Playlist>.of(playlists);
      _favorites = <String>{...favorites}.toList();
      _playCounts = Map<String, int>.of(playCounts);
      _lastPlayed = Map<String, int>.of(lastPlayed);
      _skipCounts = Map<String, int>.of(skipCounts);
      _listenedSum = Map<String, double>.of(listenedSum);
      _listenedSamples = Map<String, int>.of(listenedSamples);
      _history = <String>{...history}.take(200).toList();
    }
    notifyListeners();
    await _persist();
  }

  void _scheduleSave() {
    _saveDebouncer.run(_persist);
  }

  Future<void> _persist() async {
    await _store.save(toProfileJson());
  }

  Future<void> flush() async {
    _saveDebouncer.cancel();
    await _persist();
  }

  @override
  void dispose() {
    _saveDebouncer.cancel();
    unawaited(_persist());
    super.dispose();
  }
}
