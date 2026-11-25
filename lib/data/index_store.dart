import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

class LibraryIndex {
  const LibraryIndex({required this.songs, required this.scannedAtMs});

  final List<Song> songs;
  final int scannedAtMs;
}

/// Persiste a biblioteca em um único arquivo JSON.
///
/// Assim o app não varre o armazenamento a cada abertura: na inicialização
/// apenas lê o índice (em um isolate) e monta referências leves em memória.
class IndexStore {
  static const int schemaVersion = 1;
  static const String fileName = 'library_index.json';

  File? _cachedFile;

  Future<File> file() async {
    final cached = _cachedFile;
    if (cached != null) return cached;
    final directory = await getApplicationSupportDirectory();
    final result = File('${directory.path}/$fileName');
    _cachedFile = result;
    return result;
  }

  Future<LibraryIndex?> load() async {
    try {
      final target = await file();
      if (!await target.exists()) return null;
      final raw = await target.readAsString();
      if (raw.trim().isEmpty) return null;
      final decoded = await compute(_decodeIndex, raw);
      final rawSongs = decoded['songs'];
      final songs = <Song>[];
      if (rawSongs is List) {
        for (final item in rawSongs) {
          if (item is Map) {
            songs.add(Song.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
      final scannedAt = decoded['scannedAtMs'];
      return LibraryIndex(
        songs: songs,
        scannedAtMs: scannedAt is num ? scannedAt.toInt() : 0,
      );
    } catch (error) {
      debugPrint('IndexStore.load falhou: $error');
      return null;
    }
  }

  Future<void> save(List<Song> songs) async {
    final payload = <String, dynamic>{
      'app': 'RepSound',
      'version': schemaVersion,
      'scannedAtMs': DateTime.now().millisecondsSinceEpoch,
      'count': songs.length,
      'songs': songs.map((song) => song.toJson()).toList(growable: false),
    };
    final raw = await compute(_encodeIndex, payload);
    final target = await file();
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(raw, flush: true);
    await temporary.rename(target.path);
  }

  Future<void> clear() async {
    final target = await file();
    if (await target.exists()) {
      await target.delete();
    }
  }

  Future<int> sizeBytes() async {
    final target = await file();
    if (!await target.exists()) return 0;
    return target.length();
  }

  Future<DateTime?> lastModified() async {
    final target = await file();
    if (!await target.exists()) return null;
    return target.lastModified();
  }
}

String _encodeIndex(Map<String, dynamic> payload) => jsonEncode(payload);

Map<String, dynamic> _decodeIndex(String raw) =>
    Map<String, dynamic>.from(jsonDecode(raw) as Map);
