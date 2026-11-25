import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'daily_store.dart';
import 'models.dart';
import 'playlist_controller.dart';
import 'recommendation_service.dart';
import 'style_controller.dart';

/// Playlist "Daily": gerada uma vez por dia a partir dos estilos escolhidos.
class DailyController extends ChangeNotifier {
  DailyController(this._store);

  final DailyStore _store;
  final Set<String> _styleIds = <String>{};
  final List<String> _songIds = <String>[];
  bool _autoUpdate = true;
  int _lastGeneratedMs = 0;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  Set<String> get styleIds => Set<String>.unmodifiable(_styleIds);
  List<String> get songIds => List<String>.unmodifiable(_songIds);
  bool get autoUpdate => _autoUpdate;
  int get lastGeneratedMs => _lastGeneratedMs;
  bool get hasStyles => _styleIds.isNotEmpty;
  DateTime? get lastGenerated => _lastGeneratedMs > 0
      ? DateTime.fromMillisecondsSinceEpoch(_lastGeneratedMs)
      : null;

  List<Song> resolveSongs(Map<String, Song> byId) => <Song>[
        for (final id in _songIds)
          if (byId[id] != null) byId[id]!,
      ];

  Future<void> load() async {
    final data = await _store.load();
    if (data != null) {
      final styles = data['styleIds'];
      if (styles is List) {
        _styleIds
          ..clear()
          ..addAll(styles.map((id) => id.toString()));
      }
      final songs = data['songIds'];
      if (songs is List) {
        _songIds
          ..clear()
          ..addAll(songs.map((id) => id.toString()));
      }
      _autoUpdate = data['autoUpdate'] as bool? ?? true;
      _lastGeneratedMs = (data['lastGeneratedMs'] as num?)?.toInt() ?? 0;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setStyles(Set<String> ids) async {
    _styleIds
      ..clear()
      ..addAll(ids);
    notifyListeners();
    await _save();
  }

  Future<void> setAutoUpdate(bool value) async {
    _autoUpdate = value;
    notifyListeners();
    await _save();
  }

  /// Gera na primeira abertura do dia quando a atualização automática está on.
  Future<void> ensureToday(
    List<Song> songs,
    StyleController styles,
    PlaylistController profile,
  ) async {
    if (!_autoUpdate && _songIds.isNotEmpty) return;
    final now = DateTime.now();
    final last = lastGenerated;
    if (last != null &&
        last.year == now.year &&
        last.month == now.month &&
        last.day == now.day &&
        _songIds.isNotEmpty) {
      return;
    }
    await refresh(songs, styles, profile);
  }

  Future<void> refresh(
    List<Song> songs,
    StyleController styles,
    PlaylistController profile, {
    math.Random? random,
  }) async {
    final candidates = _styleCandidates(songs, styles);
    final generated = candidates.isEmpty
        ? const <Song>[]
        : RecommendationService.daily(
            candidates,
            profile,
            random: random,
          );
    _songIds
      ..clear()
      ..addAll(generated.map((song) => song.id));
    _lastGeneratedMs = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    await _save();
  }

  List<Song> _styleCandidates(List<Song> songs, StyleController styles) {
    if (_styleIds.isEmpty) return const <Song>[];
    return <Song>[
      for (final song in songs)
        if (styles.stylesForSong(song).any(_styleIds.contains)) song,
    ];
  }

  Future<void> _save() => _store.save(<String, dynamic>{
        'version': 1,
        'styleIds': _styleIds.toList(),
        'songIds': _songIds,
        'autoUpdate': _autoUpdate,
        'lastGeneratedMs': _lastGeneratedMs,
      });
}
