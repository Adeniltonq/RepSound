import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Persiste a playlist Daily e sua configuração.
class DailyStore {
  static const String fileName = 'daily.json';

  File? _cachedFile;

  Future<File> file() async {
    final cached = _cachedFile;
    if (cached != null) return cached;
    final directory = await getApplicationSupportDirectory();
    final result = File('${directory.path}/$fileName');
    _cachedFile = result;
    return result;
  }

  Future<Map<String, dynamic>?> load() async {
    try {
      final target = await file();
      if (!await target.exists()) return null;
      final raw = await target.readAsString();
      if (raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (error) {
      debugPrint('DailyStore.load falhou: $error');
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
      debugPrint('DailyStore.save falhou: $error');
    }
  }
}
