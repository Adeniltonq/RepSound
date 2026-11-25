import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/index_store.dart';
import '../data/media_channel.dart';
import '../data/models.dart';
import '../data/playlist_controller.dart';
import '../data/song_card_cache.dart';
import '../state/settings_controller.dart';

/// Dono do índice da biblioteca e dos filtros/ordenação.
///
/// O índice completo vive no disco. Em memória ficam apenas referências leves
/// ([Song]); as capas/fichas pesadas passam pelo [SongCardCache], limitado a
/// 4× a quantidade visível.
class LibraryController extends ChangeNotifier {
  LibraryController({
    required this._media,
    required this._store,
    required this._cards,
    required this._settings,
    required this._profile,
  })  : _sortField = _settings.sortField,
        _sortAscending = _settings.sortAscending;

  final MediaChannel _media;
  final IndexStore _store;
  final SongCardCache _cards;
  final SettingsController _settings;
  final PlaylistController _profile;

  List<Song> _allSongs = <Song>[];
  List<Song> _filtered = <Song>[];
  List<Song> _recentlyAdded = <Song>[];
  Map<String, Song> _songById = <String, Song>{};
  List<String> _formats = <String>[];
  List<String> _folders = <String>[];

  SortField _sortField;
  bool _sortAscending;
  final Set<String> _formatFilters = <String>{};
  QualityFilter _qualityFilter = QualityFilter.all;
  String? _folderFilter;

  bool _isLoading = false;
  bool _isScanning = false;
  bool _supported = true;
  bool _permissionBlocked = false;
  String? _error;
  int _lastScanMs = 0;

  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;
  bool get supported => _supported;
  bool get permissionBlocked => _permissionBlocked;
  String? get error => _error;
  int get lastScanMs => _lastScanMs;

  List<Song> get songs => UnmodifiableListView<Song>(_allSongs);
  List<Song> get filteredSongs => UnmodifiableListView<Song>(_filtered);
  Map<String, Song> get songById => UnmodifiableMapView<String, Song>(_songById);
  List<String> get formats => UnmodifiableListView<String>(_formats);
  List<String> get folders => UnmodifiableListView<String>(_folders);
  List<Song> get recentlyAdded => UnmodifiableListView<Song>(_recentlyAdded);

  SortField get sortField => _sortField;
  bool get sortAscending => _sortAscending;
  Set<String> get formatFilters => Set<String>.unmodifiable(_formatFilters);
  QualityFilter get qualityFilter => _qualityFilter;
  String? get folderFilter => _folderFilter;
  bool get hasActiveFilters =>
      _formatFilters.isNotEmpty ||
      _qualityFilter != QualityFilter.all ||
      _folderFilter != null;

  int get totalSongs => _allSongs.length;
  int get totalArtists => _allSongs.map((song) => song.artist).toSet().length;
  int get totalAlbums => _allSongs.map((song) => song.album).toSet().length;
  int get totalDurationMs =>
      _allSongs.fold<int>(0, (sum, song) => sum + song.durationMs);

  Song? byId(String? id) => id == null ? null : _songById[id];

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _supported = await _media.checkSupported();
      final index = await _store.load();
      if (index != null) {
        _setSongs(index.songs);
        _lastScanMs = index.scannedAtMs;
      }
    } catch (error) {
      _error = 'Não foi possível abrir o índice da biblioteca.';
      debugPrint('LibraryController.load: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Varre o MediaStore (inclui cartão SD) e regrava o arquivo de índice.
  Future<bool> scan() async {
    if (_isScanning) return false;
    _isScanning = true;
    _error = null;
    notifyListeners();
    try {
      if (!await ensurePermissions()) {
        _error = 'Permita o acesso às músicas para montar a biblioteca.';
        return false;
      }
      final rawSongs = await _media.querySongs();
      if (!_media.supported) {
        _error = 'A leitura automática da biblioteca está disponível no Android.';
        return false;
      }
      final minDuration = _settings.minDurationSec * 1000;
      final result = <Song>[];
      final seen = <String>{};
      for (final song in rawSongs) {
        if (song.contentUri.isEmpty) continue;
        if (song.durationMs > 0 && song.durationMs < minDuration) continue;
        if (seen.add(song.id)) result.add(song);
      }
      _setSongs(result);
      _lastScanMs = DateTime.now().millisecondsSinceEpoch;
      await _store.save(result);
      await _cards.clearDisk();
      await requestNotificationPermission();
      notifyListeners();
      return true;
    } on MediaException catch (error) {
      _error = error.message;
      return false;
    } catch (error) {
      _error = 'Falha ao escanear a biblioteca. Tente novamente.';
      debugPrint('LibraryController.scan: $error');
      return false;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<bool> ensurePermissions() async {
    if (kIsWeb) return false;
    if (!Platform.isAndroid) return true;
    final audio = await Permission.audio.status;
    if (audio.isGranted) {
      _permissionBlocked = false;
      return true;
    }
    final storage = await Permission.storage.status;
    if (storage.isGranted) {
      _permissionBlocked = false;
      return true;
    }
    final results = await <Permission>[
      Permission.audio,
      Permission.storage,
    ].request();
    final granted = results.values.any((status) => status.isGranted);
    _permissionBlocked = !granted &&
        results.values.any((status) => status.isPermanentlyDenied);
    return granted;
  }

  /// Abre a tela de permissões do app no sistema (quando o usuário marcou
  /// "não perguntar novamente").
  Future<bool> openSystemSettings() => openAppSettings();

  Future<void> requestNotificationPermission() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted && !status.isPermanentlyDenied) {
        await Permission.notification.request();
      }
    } catch (_) {
      // Notificação é opcional.
    }
  }

  Future<void> clearIndex() async {
    await _store.clear();
    _setSongs(const <Song>[]);
    _lastScanMs = 0;
    notifyListeners();
  }

  /// Exclui arquivos pelo MediaStore e remove as faixas do índice.
  Future<int> deleteSongs(Iterable<Song> songs) async {
    final list = songs.toList(growable: false);
    if (list.isEmpty) return 0;
    final deleted = await _media.deleteSongs(list);
    if (deleted > 0) {
      await removeSongsByIds(<String>{for (final song in list) song.id});
    }
    return deleted;
  }

  /// Remove faixas do índice (sem tocar nos arquivos).
  Future<void> removeSongsByIds(Set<String> ids) async {
    if (ids.isEmpty) return;
    final remaining = <Song>[
      for (final song in _allSongs)
        if (!ids.contains(song.id)) song,
    ];
    if (remaining.length == _allSongs.length) return;
    _setSongs(remaining);
    await _store.save(_allSongs);
    notifyListeners();
  }

  void _setSongs(List<Song> songs) {
    _allSongs = List<Song>.of(songs);
    _songById = <String, Song>{
      for (final song in _allSongs) song.id: song,
    };
    _formats = _allSongs.map((song) => song.format).toSet().toList()..sort();
    _folders = _allSongs.map((song) => song.folder).toSet().toList()..sort();
    _recentlyAdded = List<Song>.of(_allSongs)
      ..sort((a, b) => b.dateAddedMs.compareTo(a.dateAddedMs));
    _applyFilters(notify: false);
  }

  // ---------------------------------------------------------------- filters

  void setSortField(SortField field) {
    if (_sortField == field) return;
    _sortField = field;
    _settings.setSortField(field);
    _applyFilters();
  }

  void toggleSortDirection() {
    _sortAscending = !_sortAscending;
    _settings.setSortAscending(_sortAscending);
    _applyFilters();
  }

  void toggleFormat(String format) {
    if (!_formatFilters.add(format)) {
      _formatFilters.remove(format);
    }
    _applyFilters();
  }

  void setQualityFilter(QualityFilter value) {
    if (_qualityFilter == value) return;
    _qualityFilter = value;
    _applyFilters();
  }

  void setFolderFilter(String? folder) {
    if (_folderFilter == folder) return;
    _folderFilter = folder;
    _applyFilters();
  }

  void clearFilters() {
    if (!hasActiveFilters) return;
    _formatFilters.clear();
    _qualityFilter = QualityFilter.all;
    _folderFilter = null;
    _applyFilters();
  }

  void _applyFilters({bool notify = true}) {
    final result = <Song>[];
    for (final song in _allSongs) {
      if (_formatFilters.isNotEmpty && !_formatFilters.contains(song.format)) {
        continue;
      }
      if (!_qualityFilter.matches(song)) continue;
      if (_folderFilter != null && song.folder != _folderFilter) continue;
      result.add(song);
    }
    result.sort(_compare);
    _filtered = result;
    if (notify) notifyListeners();
  }

  int _compare(Song a, Song b) {
    int result;
    switch (_sortField) {
      case SortField.title:
        result = a.titleKey.compareTo(b.titleKey);
        if (result == 0) result = a.artistKey.compareTo(b.artistKey);
        break;
      case SortField.artist:
        result = a.artistKey.compareTo(b.artistKey);
        if (result == 0) result = a.albumKey.compareTo(b.albumKey);
        if (result == 0) result = a.titleKey.compareTo(b.titleKey);
        break;
      case SortField.album:
        result = a.albumKey.compareTo(b.albumKey);
        if (result == 0) result = a.track.compareTo(b.track);
        if (result == 0) result = a.titleKey.compareTo(b.titleKey);
        break;
      case SortField.dateAdded:
        result = a.dateAddedMs.compareTo(b.dateAddedMs);
        if (result == 0) result = a.titleKey.compareTo(b.titleKey);
        break;
      case SortField.duration:
        result = a.durationMs.compareTo(b.durationMs);
        if (result == 0) result = a.titleKey.compareTo(b.titleKey);
        break;
      case SortField.format:
        result = a.format.compareTo(b.format);
        if (result == 0) result = a.titleKey.compareTo(b.titleKey);
        break;
      case SortField.quality:
        result = a.quality.index.compareTo(b.quality.index);
        if (result == 0) result = a.titleKey.compareTo(b.titleKey);
        break;
      case SortField.plays:
        result = _profile.playCountFor(a.id).compareTo(
              _profile.playCountFor(b.id),
            );
        if (result == 0) {
          result = _profile.lastPlayedFor(a.id).compareTo(
                _profile.lastPlayedFor(b.id),
              );
        }
        if (result == 0) result = a.titleKey.compareTo(b.titleKey);
        break;
      case SortField.folder:
        result = a.folderKey.compareTo(b.folderKey);
        if (result == 0) result = a.titleKey.compareTo(b.titleKey);
        break;
    }
    return _sortAscending ? result : -result;
  }

  // ------------------------------------------------------------- collection

  List<Song> collectionSongs(SongCollectionKind kind, {int limit = 500}) {
    switch (kind) {
      case SongCollectionKind.favorites:
        return _mapIds(_profile.favorites, limit);
      case SongCollectionKind.recent:
        return _mapIds(_profile.history, limit);
      case SongCollectionKind.mostPlayed:
        final entries = _profile.playCounts.entries
            .where((entry) => _songById.containsKey(entry.key))
            .toList()
          ..sort((a, b) {
            final byCount = b.value.compareTo(a.value);
            if (byCount != 0) return byCount;
            return _profile
                .lastPlayedFor(b.key)
                .compareTo(_profile.lastPlayedFor(a.key));
          });
        return entries
            .take(limit)
            .map((entry) => _songById[entry.key])
            .whereType<Song>()
            .toList();
      case SongCollectionKind.recentlyAdded:
        return _recentlyAdded.take(limit).toList();
    }
  }

  int collectionCount(SongCollectionKind kind) => switch (kind) {
        SongCollectionKind.favorites => _profile.favorites.length,
        SongCollectionKind.recent => _profile.history.length,
        SongCollectionKind.mostPlayed => _profile.playCounts.length,
        SongCollectionKind.recentlyAdded => _allSongs.length,
      };

  List<Song> _mapIds(List<String> ids, int limit) {
    final result = <Song>[];
    for (final id in ids) {
      final song = _songById[id];
      if (song != null) {
        result.add(song);
        if (result.length >= limit) break;
      }
    }
    return result;
  }

  // ------------------------------------------------------------- diagnostic

  Future<int> indexSizeBytes() => _store.sizeBytes();

  Future<DateTime?> indexLastModified() => _store.lastModified();

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
