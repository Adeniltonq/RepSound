import 'package:flutter/services.dart';

import 'models.dart';

class MediaException implements Exception {
  MediaException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Canal com o código nativo (MediaStore no Android).
///
/// A leitura acontece fora da thread de UI no lado nativo; o Dart recebe
/// apenas os metadados. Capas são pedidas uma a uma, sob demanda.
class MediaChannel {
  static const MethodChannel _channel = MethodChannel('com.repsound/media');

  bool _supported = true;
  bool get supported => _supported;

  Future<bool> checkSupported() async {
    try {
      final value = await _channel.invokeMethod<bool>('isSupported');
      _supported = value ?? false;
      return _supported;
    } on MissingPluginException {
      _supported = false;
      return false;
    } catch (_) {
      _supported = false;
      return false;
    }
  }

  Future<List<Song>> querySongs() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('querySongs');
      _supported = true;
      if (raw == null || raw.isEmpty) return const <Song>[];
      final songs = <Song>[];
      for (final item in raw) {
        if (item is Map) {
          songs.add(Song.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      return songs;
    } on MissingPluginException {
      _supported = false;
      return const <Song>[];
    } on PlatformException catch (error) {
      throw MediaException(
        error.message ?? 'Não foi possível ler a biblioteca de áudio.',
      );
    }
  }

  Future<Uint8List?> queryArtwork(Song song, {int size = 320}) async {
    try {
      return await _channel.invokeMethod<Uint8List>('queryArtwork', {
        'volume': song.volume,
        'mediaId': song.mediaId,
        'size': size,
      });
    } on MissingPluginException {
      _supported = false;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Exclui os arquivos pelo MediaStore. Em Android 11+ o sistema pede
  /// confirmação ao usuário antes de apagar.
  Future<int> deleteSongs(Iterable<Song> songs) async {
    final items = <Map<String, dynamic>>[
      for (final song in songs)
        <String, dynamic>{'volume': song.volume, 'mediaId': song.mediaId},
    ];
    if (items.isEmpty) return 0;
    try {
      final deleted = await _channel.invokeMethod<int>('deleteSongs', {
        'items': items,
      });
      return deleted ?? 0;
    } on MissingPluginException {
      throw MediaException('A exclusão de arquivos não está disponível.');
    } on PlatformException catch (error) {
      throw MediaException(
        error.message ?? 'Não foi possível excluir os arquivos.',
      );
    }
  }

  /// Consome o pedido de abrir a reprodução vindo do toque na notificação.
  static Future<bool> consumeOpenPlayer() async {
    try {
      final value = await _channel.invokeMethod<bool>('consumeOpenPlayer');
      return value ?? false;
    } catch (_) {
      return false;
    }
  }
}
