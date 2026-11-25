import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Persiste estilos, atribuições e a configuração da Daily.
class StyleStore {
  static const String fileName = 'styles.json';

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
      debugPrint('StyleStore.load falhou: $error');
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
      debugPrint('StyleStore.save falhou: $error');
    }
  }
}
