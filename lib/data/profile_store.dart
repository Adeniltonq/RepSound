import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Arquivo único do perfil: playlists, favoritos e estatísticas.
class ProfileStore {
  static const String fileName = 'profile.json';

  File? _cachedFile;

  Future<File> file() async {
    final cached = _cachedFile;
    if (cached != null) return cached;
    final directory = await getApplicationSupportDirectory();
    final result = File('${directory.path}/$fileName');
    _cachedFile = result;
    return result;
  }

  Future<Directory> backupDirectory() async {
    final directory = await getApplicationSupportDirectory();
    final backup = Directory('${directory.path}/backups');
    if (!await backup.exists()) {
      await backup.create(recursive: true);
    }
    return backup;
  }

  Future<Map<String, dynamic>?> load() async {
    try {
      final target = await file();
      if (!await target.exists()) return null;
      final raw = await target.readAsString();
      if (raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (error) {
      debugPrint('ProfileStore.load falhou: $error');
      return null;
    }
  }

  Future<void> save(Map<String, dynamic> data) async {
    try {
      final target = await file();
      final temporary = File('${target.path}.tmp');
      await temporary.writeAsString(jsonEncode(data), flush: true);
      await temporary.rename(target.path);
    } catch (error) {
      debugPrint('ProfileStore.save falhou: $error');
    }
  }

  Future<int> sizeBytes() async {
    final target = await file();
    if (!await target.exists()) return 0;
    return target.length();
  }
}
