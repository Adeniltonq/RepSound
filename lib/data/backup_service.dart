import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/utils.dart';
import '../state/library_controller.dart';
import '../state/settings_controller.dart';
import 'models.dart';
import 'playlist_controller.dart';
import 'profile_store.dart';

enum ImportMode { merge, replace }

class ImportResult {
  const ImportResult({
    required this.playlists,
    required this.favorites,
    required this.unmatched,
    required this.fromCsv,
  });

  final int playlists;
  final int favorites;
  final int unmatched;
  final bool fromCsv;

  String get message {
    final parts = <String>[
      if (playlists > 0) '$playlists playlist(s)',
      if (favorites > 0) '$favorites favorito(s)',
      if (unmatched > 0) '$unmatched faixa(s) não encontradas',
    ];
    if (parts.isEmpty) return 'Perfil importado.';
    return 'Perfil importado: ${parts.join(', ')}.';
  }
}

class BackupException implements Exception {
  BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Exporta/importa o perfil (JSON ou CSV) e mantém o backup automático.
///
/// Não há login: o arquivo é compartilhado pelo menu do sistema, então pode
/// ser salvo no Drive, Nextcloud, Dropbox ou em qualquer pasta sincronizada.
class BackupService {
  BackupService({
    required this.store,
    required this.settings,
    required this.playlists,
    required this.library,
  });

  final ProfileStore store;
  final SettingsController settings;
  final PlaylistController playlists;
  final LibraryController library;

  Timer? _autoTimer;
  bool _started = false;
  bool _writing = false;

  // --------------------------------------------------------------- export

  Map<String, dynamic> buildProfileJson() {
    final byId = library.songById;
    final playlistData = <Map<String, dynamic>>[];
    for (final playlist in playlists.playlists) {
      final songs = <Map<String, dynamic>>[];
      for (final id in playlist.songIds) {
        final song = byId[id];
        songs.add(song?.toRefJson() ?? <String, dynamic>{'id': id});
      }
      playlistData.add(<String, dynamic>{
        'id': playlist.id,
        'name': playlist.name,
        'createdAtMs': playlist.createdAtMs,
        'updatedAtMs': playlist.updatedAtMs,
        'songs': songs,
      });
    }

    final favoriteData = <Map<String, dynamic>>[];
    for (final id in playlists.favorites) {
      final song = byId[id];
      favoriteData.add(song?.toRefJson() ?? <String, dynamic>{'id': id});
    }

    return <String, dynamic>{
      'app': 'RepSound',
      'version': 1,
      'exportedAtMs': DateTime.now().millisecondsSinceEpoch,
      'settings': settings.toJson(),
      'playlists': playlistData,
      'favorites': favoriteData,
      'stats': <String, dynamic>{
        'playCounts': playlists.playCounts,
        'lastPlayed': playlists.lastPlayed,
        'skipCounts': playlists.skipCounts,
        'listenedSum': playlists.listenedSum,
        'listenedSamples': playlists.listenedSamples,
        'history': playlists.history,
      },
      'library': <String, dynamic>{
        'songCount': library.totalSongs,
        'lastScanMs': library.lastScanMs,
      },
    };
  }

  Future<File> writeJsonFile() async {
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/repsound_perfil_${_timestamp()}.json',
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(buildProfileJson()),
      flush: true,
    );
    settings.markBackupDone();
    return file;
  }

  Future<File> writeCsvFile() async {
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/repsound_perfil_${_timestamp()}.csv',
    );
    await file.writeAsString(_buildCsv(), flush: true);
    settings.markBackupDone();
    return file;
  }

  Future<void> shareJson() async {
    final file = await writeJsonFile();
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[
          XFile(file.path, mimeType: 'application/json'),
        ],
        subject: 'RepSound — perfil (JSON)',
        text: 'Backup do RepSound com playlists, favoritos e ajustes.',
      ),
    );
  }

  Future<void> shareCsv() async {
    final file = await writeCsvFile();
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[
          XFile(file.path, mimeType: 'text/csv'),
        ],
        subject: 'RepSound — perfil (CSV)',
        text: 'Backup do RepSound com playlists, favoritos e ajustes.',
      ),
    );
  }

  String _buildCsv() {
    final byId = library.songById;
    final rows = <List<String>>[
      <String>[
        'tipo',
        'playlist',
        'musica_id',
        'titulo',
        'artista',
        'album',
        'caminho',
        'duracao_ms',
        'favorito',
        'reproducoes',
        'valor',
      ],
    ];

    void addSongRows(String type, String playlistName, List<String> ids) {
      for (final id in ids) {
        final song = byId[id];
        rows.add(<String>[
          type,
          playlistName,
          id,
          song?.title ?? '',
          song?.artist ?? '',
          song?.album ?? '',
          song?.path ?? '',
          song == null ? '' : song.durationMs.toString(),
          type == 'favorito' ? '1' : '0',
          playlists.playCountFor(id).toString(),
          '',
        ]);
      }
    }

    for (final playlist in playlists.playlists) {
      addSongRows('playlist', playlist.name, playlist.songIds);
    }
    addSongRows('favorito', 'Favoritos', playlists.favorites);

    rows.add(<String>[
      'configuracao',
      'settings',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      jsonEncode(settings.toJson()),
    ]);
    rows.add(<String>[
      'configuracao',
      'estatisticas',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      jsonEncode(<String, dynamic>{
        'playCounts': playlists.playCounts,
        'lastPlayed': playlists.lastPlayed,
        'skipCounts': playlists.skipCounts,
        'listenedSum': playlists.listenedSum,
        'listenedSamples': playlists.listenedSamples,
        'history': playlists.history,
      }),
    ]);

    final buffer = StringBuffer('\uFEFF');
    for (final row in rows) {
      buffer.writeln(row.map(_escapeCsv).join(','));
    }
    return buffer.toString();
  }

  // --------------------------------------------------------------- import

  Future<ImportResult?> pickAndImport({ImportMode mode = ImportMode.merge}) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['json', 'csv'],
    );
    if (picked.isEmpty) return null;
    final file = picked.first;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw BackupException('Não foi possível ler o arquivo escolhido.');
    }
    final text = utf8
        .decode(bytes, allowMalformed: true)
        .replaceFirst('\uFEFF', '');
    final isCsv = file.extension?.toLowerCase() == 'csv' ||
        (!text.trimLeft().startsWith('{') && text.contains(','));
    if (isCsv) {
      return importCsv(text, mode: mode);
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw BackupException('Arquivo JSON inválido.');
    }
    return importJson(Map<String, dynamic>.from(decoded), mode: mode);
  }

  Future<ImportResult> importJson(
    Map<String, dynamic> data, {
    ImportMode mode = ImportMode.merge,
  }) async {
    final lookup = _SongLookup(library);
    var unmatched = 0;

    final incomingPlaylists = <Playlist>[];
    final rawPlaylists = data['playlists'];
    if (rawPlaylists is List) {
      for (final raw in rawPlaylists.whereType<Map>()) {
        final playlistMap = Map<String, dynamic>.from(raw);
        final ids = <String>[];
        final rawSongs = playlistMap['songs'];
        if (rawSongs is List) {
          for (final rawSong in rawSongs) {
            if (rawSong is Map) {
              final id = lookup.resolve(Map<String, dynamic>.from(rawSong));
              if (id == null) {
                unmatched++;
              } else if (!ids.contains(id)) {
                ids.add(id);
              }
            }
          }
        } else {
          final rawIds = playlistMap['songIds'];
          if (rawIds is List) {
            for (final rawId in rawIds) {
              final id = rawId.toString();
              if (lookup.exists(id)) {
                if (!ids.contains(id)) ids.add(id);
              } else {
                unmatched++;
              }
            }
          }
        }
        incomingPlaylists.add(
          Playlist(
            id: playlistMap['id'] as String? ??
                'pl_${DateTime.now().microsecondsSinceEpoch}_${incomingPlaylists.length}',
            name: playlistMap['name'] as String? ?? 'Playlist importada',
            songIds: ids,
            createdAtMs: _asInt(playlistMap['createdAtMs']),
            updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
    }

    final incomingFavorites = <String>[];
    final rawFavorites = data['favorites'];
    if (rawFavorites is List) {
      for (final raw in rawFavorites) {
        if (raw is Map) {
          final id = lookup.resolve(Map<String, dynamic>.from(raw));
          if (id == null) {
            unmatched++;
          } else if (!incomingFavorites.contains(id)) {
            incomingFavorites.add(id);
          }
        } else {
          final id = raw.toString();
          if (lookup.exists(id)) {
            if (!incomingFavorites.contains(id)) incomingFavorites.add(id);
          }
        }
      }
    }

    final incomingPlayCounts = <String, int>{};
    final incomingLastPlayed = <String, int>{};
    final incomingSkipCounts = <String, int>{};
    final incomingListenedSum = <String, double>{};
    final incomingListenedSamples = <String, int>{};
    var incomingHistory = <String>[];
    final stats = data['stats'];
    if (stats is Map) {
      final counts = stats['playCounts'];
      if (counts is Map) {
        counts.forEach((key, value) {
          if (value is num && lookup.exists(key.toString())) {
            incomingPlayCounts[key.toString()] = value.toInt();
          }
        });
      }
      final lastPlayed = stats['lastPlayed'];
      if (lastPlayed is Map) {
        lastPlayed.forEach((key, value) {
          if (value is num && lookup.exists(key.toString())) {
            incomingLastPlayed[key.toString()] = value.toInt();
          }
        });
      }
      final skips = stats['skipCounts'];
      if (skips is Map) {
        skips.forEach((key, value) {
          if (value is num && lookup.exists(key.toString())) {
            incomingSkipCounts[key.toString()] = value.toInt();
          }
        });
      }
      final listenedSum = stats['listenedSum'];
      if (listenedSum is Map) {
        listenedSum.forEach((key, value) {
          if (value is num && lookup.exists(key.toString())) {
            incomingListenedSum[key.toString()] = value.toDouble();
          }
        });
      }
      final listenedSamples = stats['listenedSamples'];
      if (listenedSamples is Map) {
        listenedSamples.forEach((key, value) {
          if (value is num && lookup.exists(key.toString())) {
            incomingListenedSamples[key.toString()] = value.toInt();
          }
        });
      }
      final history = stats['history'];
      if (history is List) {
        incomingHistory = history
            .map((entry) => entry.toString())
            .where(lookup.exists)
            .toList();
      }
    }

    final rawSettings = data['settings'];
    if (rawSettings is Map) {
      await settings.applyJson(Map<String, dynamic>.from(rawSettings));
    }

    await playlists.importData(
      playlists: incomingPlaylists,
      favorites: incomingFavorites,
      playCounts: incomingPlayCounts,
      lastPlayed: incomingLastPlayed,
      skipCounts: incomingSkipCounts,
      listenedSum: incomingListenedSum,
      listenedSamples: incomingListenedSamples,
      history: incomingHistory,
      merge: mode == ImportMode.merge,
    );

    return ImportResult(
      playlists: incomingPlaylists.length,
      favorites: incomingFavorites.length,
      unmatched: unmatched,
      fromCsv: false,
    );
  }

  Future<ImportResult> importCsv(
    String content, {
    ImportMode mode = ImportMode.merge,
  }) async {
    final rows = _parseCsv(content.replaceFirst('\uFEFF', ''));
    if (rows.isEmpty) {
      throw BackupException('CSV vazio.');
    }
    final header = rows.first.map((value) => value.toLowerCase()).toList();
    final hasHeader = header.contains('tipo') && header.contains('playlist');
    final dataRows = hasHeader ? rows.skip(1) : rows;

    final playlistsByName = <String, List<Map<String, dynamic>>>{};
    final favorites = <Map<String, dynamic>>[];
    Map<String, dynamic>? importedSettings;
    Map<String, dynamic>? importedStats;

    for (final row in dataRows) {
      if (row.length < 2) continue;
      final type = row[0].trim().toLowerCase();
      if (type == 'playlist') {
        final name = _cell(row, 1, fallback: 'Playlist importada');
        playlistsByName.putIfAbsent(name, () => <Map<String, dynamic>>[]).add(
              _refFromCsvRow(row),
            );
      } else if (type == 'favorito') {
        favorites.add(_refFromCsvRow(row));
      } else if (type == 'configuracao') {
        final key = _cell(row, 1);
        final value = _cell(row, 10);
        if (key == 'settings') {
          final decoded = jsonDecode(value);
          if (decoded is Map) {
            importedSettings = Map<String, dynamic>.from(decoded);
          }
        } else if (key == 'estatisticas') {
          final decoded = jsonDecode(value);
          if (decoded is Map) {
            importedStats = Map<String, dynamic>.from(decoded);
          }
        }
      }
    }

    final profile = <String, dynamic>{
      'settings': importedSettings ?? <String, dynamic>{},
      'playlists': <Map<String, dynamic>>[
        for (final entry in playlistsByName.entries)
          <String, dynamic>{'name': entry.key, 'songs': entry.value},
      ],
      'favorites': favorites,
      'stats': importedStats ?? <String, dynamic>{},
    };

    final result = await importJson(profile, mode: mode);
    return ImportResult(
      playlists: result.playlists,
      favorites: result.favorites,
      unmatched: result.unmatched,
      fromCsv: true,
    );
  }

  Map<String, dynamic> _refFromCsvRow(List<String> row) => <String, dynamic>{
        'id': _cell(row, 2),
        'title': _cell(row, 3),
        'artist': _cell(row, 4),
        'album': _cell(row, 5),
        'path': _cell(row, 6),
        'durationMs': int.tryParse(_cell(row, 7)) ?? 0,
      };

  // ------------------------------------------------------------ auto backup

  void startAutoBackup() {
    if (_started) return;
    _started = true;
    playlists.addListener(_schedule);
    settings.addListener(_schedule);
  }

  void _schedule() {
    if (!_started || _writing || !settings.autoBackup) return;
    _autoTimer?.cancel();
    _autoTimer = Timer(const Duration(seconds: 8), () {
      unawaited(writeAutoBackup());
    });
  }

  Future<File> writeAutoBackup() async {
    _writing = true;
    try {
      final directory = await store.backupDirectory();
      final file = File('${directory.path}/auto_backup.json');
      await file.writeAsString(jsonEncode(buildProfileJson()), flush: true);
      settings.markBackupDone();
      return file;
    } finally {
      _writing = false;
    }
  }

  Future<void> dispose() async {
    _started = false;
    _autoTimer?.cancel();
    playlists.removeListener(_schedule);
    settings.removeListener(_schedule);
  }
}

class _SongLookup {
  _SongLookup(LibraryController library) {
    for (final song in library.songs) {
      _ids.add(song.id);
      if (song.path != null && song.path!.isNotEmpty) {
        _byPath[song.path!] = song.id;
      }
      _byTitleArtist['${song.titleKey}|${song.artistKey}'] = song.id;
      _byTitle.putIfAbsent(song.titleKey, () => song.id);
    }
  }

  final Set<String> _ids = <String>{};
  final Map<String, String> _byPath = <String, String>{};
  final Map<String, String> _byTitleArtist = <String, String>{};
  final Map<String, String> _byTitle = <String, String>{};

  bool exists(String id) => _ids.contains(id);

  String? resolve(Map<String, dynamic> ref) {
    final id = ref['id']?.toString();
    if (id != null && _ids.contains(id)) return id;
    final path = ref['path']?.toString();
    if (path != null && path.isNotEmpty) {
      final byPath = _byPath[path];
      if (byPath != null) return byPath;
    }
    final title = normalizeForSearch(ref['title']?.toString() ?? '');
    if (title.isEmpty) return null;
    final artist = normalizeForSearch(ref['artist']?.toString() ?? '');
    final byBoth = _byTitleArtist['$title|$artist'];
    if (byBoth != null) return byBoth;
    return _byTitle[title];
  }
}

String _timestamp() {
  final now = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${now.year}${two(now.month)}${two(now.day)}_'
      '${two(now.hour)}${two(now.minute)}';
}

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _cell(List<String> row, int index, {String fallback = ''}) {
  if (index < 0 || index >= row.length) return fallback;
  final value = row[index].trim();
  return value.isEmpty ? fallback : value;
}

String _escapeCsv(String value) {
  if (value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

List<List<String>> _parseCsv(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;

  for (var index = 0; index < input.length; index++) {
    final char = input[index];
    if (inQuotes) {
      if (char == '"') {
        if (index + 1 < input.length && input[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(char);
      }
      continue;
    }
    if (char == '"') {
      inQuotes = true;
    } else if (char == ',') {
      row.add(field.toString());
      field.clear();
    } else if (char == '\n') {
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else if (char == '\r') {
      // ignora CR
    } else {
      field.write(char);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}
