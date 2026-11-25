import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils.dart';
import 'models.dart';
import 'style_models.dart';
import 'style_store.dart';

/// Estilos do usuário e suas atribuições (faixa, álbum ou artista).
class StyleController extends ChangeNotifier {
  StyleController(this._store);

  final StyleStore _store;
  final List<SongStyle> _styles = <SongStyle>[];
  final Map<String, Set<String>> _songStyles = <String, Set<String>>{};
  final Map<String, Set<String>> _albumStyles = <String, Set<String>>{};
  final Map<String, Set<String>> _artistStyles = <String, Set<String>>{};
  Timer? _saveTimer;
  bool _loaded = false;

  List<SongStyle> get styles => List<SongStyle>.unmodifiable(_styles);
  bool get isLoaded => _loaded;
  int get count => _styles.length;

  Future<void> load() async {
    final data = await _store.load();
    if (data != null) _apply(data);
    _loaded = true;
    notifyListeners();
  }

  void _apply(Map<String, dynamic> data) {
    final rawStyles = data['styles'];
    if (rawStyles is List) {
      _styles
        ..clear()
        ..addAll(
          rawStyles
              .whereType<Map>()
              .map((entry) => SongStyle.fromJson(Map<String, dynamic>.from(entry))),
        );
    }
    _readMap(data['songs'], _songStyles);
    _readMap(data['albums'], _albumStyles);
    _readMap(data['artists'], _artistStyles);
  }

  static void _readMap(dynamic raw, Map<String, Set<String>> target) {
    target.clear();
    if (raw is! Map) return;
    raw.forEach((key, value) {
      if (value is List) {
        final ids = value.map((entry) => entry.toString()).toSet();
        if (ids.isNotEmpty) target[key.toString()] = ids;
      }
    });
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> encode(Map<String, Set<String>> map) =>
        <String, dynamic>{
          for (final entry in map.entries)
            if (entry.value.isNotEmpty) entry.key: entry.value.toList(),
        };
    return <String, dynamic>{
      'app': 'RepSound',
      'version': 1,
      'styles': _styles.map((style) => style.toJson()).toList(),
      'songs': encode(_songStyles),
      'albums': encode(_albumStyles),
      'artists': encode(_artistStyles),
    };
  }

  SongStyle? styleById(String id) {
    for (final style in _styles) {
      if (style.id == id) return style;
    }
    return null;
  }

  Future<SongStyle> create(String name, int colorValue) async {
    final style = SongStyle(
      id: 'style_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      colorValue: colorValue,
    );
    _styles.add(style);
    notifyListeners();
    _scheduleSave();
    return style;
  }

  void update(String id, {String? name, int? colorValue}) {
    final index = _styles.indexWhere((style) => style.id == id);
    if (index < 0) return;
    _styles[index] = _styles[index].copyWith(name: name, colorValue: colorValue);
    notifyListeners();
    _scheduleSave();
  }

  void delete(String id) {
    _styles.removeWhere((style) => style.id == id);
    for (final map in <Map<String, Set<String>>>[
      _songStyles,
      _albumStyles,
      _artistStyles,
    ]) {
      for (final entry in map.entries) {
        entry.value.remove(id);
      }
      map.removeWhere((key, value) => value.isEmpty);
    }
    notifyListeners();
    _scheduleSave();
  }

  /// Estilos efetivos: faixa própria > álbum/artista.
  Set<String> stylesForSong(Song song) {
    final direct = _songStyles[song.id];
    if (direct != null && direct.isNotEmpty) return Set<String>.of(direct);
    return <String>{
      ...?_albumStyles[albumStyleKey(song)],
      ...?_artistStyles[artistStyleKey(song)],
    };
  }

  bool songHasStyle(Song song, String styleId) =>
      stylesForSong(song).contains(styleId);

  List<Song> songsWithStyle(List<Song> songs, String styleId) => <Song>[
        for (final song in songs)
          if (songHasStyle(song, styleId)) song,
      ];

  /// Aplica (ou remove) estilos ao alvo escolhido.
  void applyStyles({
    required Set<String> styleIds,
    required Iterable<Song> songs,
    required StyleTarget target,
  }) {
    for (final song in songs) {
      final map = switch (target) {
        StyleTarget.song => _songStyles,
        StyleTarget.album => _albumStyles,
        StyleTarget.artist => _artistStyles,
      };
      final key = switch (target) {
        StyleTarget.song => song.id,
        StyleTarget.album => albumStyleKey(song),
        StyleTarget.artist => artistStyleKey(song),
      };
      final valid = <String>{
        for (final id in styleIds)
          if (styleById(id) != null) id,
      };
      if (valid.isEmpty) {
        map.remove(key);
      } else {
        map[key] = valid;
      }
    }
    notifyListeners();
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(_store.save(toJson()));
    });
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    await _store.save(toJson());
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(_store.save(toJson()));
    super.dispose();
  }
}

/// Chave usada para agrupar álbuns nas recomendações.
String styleAlbumKey(Song song) =>
    '${normalizeForSearch(song.artist)}|${normalizeForSearch(song.album)}';
