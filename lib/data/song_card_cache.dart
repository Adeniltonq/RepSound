import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/utils.dart';
import 'media_channel.dart';
import 'models.dart';

/// A "ficha" completa de uma faixa: metadados + capa.
class SongCard {
  const SongCard({required this.song, required this.artwork});

  final Song song;
  final Uint8List? artwork;

  bool get hasArtwork => artwork != null && artwork!.isNotEmpty;
}

/// Cache em janela deslizante.
///
/// Regra do projeto: no máximo **4 × a quantidade visível** de fichas em
/// memória (10 faixas na tela → 40 fichas). Ao rolar, a ficha mais antiga sai
/// de um lado da janela e a nova entra do outro (LRU), sem nunca carregar a
/// biblioteca inteira.
class SongCardCache extends ChangeNotifier {
  SongCardCache._(this._media, this._directory);

  final MediaChannel _media;
  final Directory _directory;

  final Map<String, SongCard> _cards = <String, SongCard>{};
  final List<String> _order = <String>[];
  final Map<String, Future<SongCard>> _inflight = <String, Future<SongCard>>{};

  int _visibleCount = 12;
  int _capacity = 48;
  int _bytes = 0;
  int _artworkSize = 320;
  static const int _maxBytes = 36 * 1024 * 1024;

  int _memoryHits = 0;
  int _diskHits = 0;
  int _nativeLoads = 0;

  int get visibleCount => _visibleCount;
  int get capacity => _capacity;
  int get artworkSize => _artworkSize;
  int get loadedCards => _cards.length;
  int get memoryBytes => _bytes;
  int get memoryHits => _memoryHits;
  int get diskHits => _diskHits;
  int get nativeLoads => _nativeLoads;

  /// Ajusta a resolução das capas (perfil de qualidade). Como os arquivos em
  /// disco guardam a resolução antiga, o cache é limpo quando o valor muda.
  void setArtworkSize(int value) {
    final next = value.clamp(96, 1024).toInt();
    if (next == _artworkSize) return;
    _artworkSize = next;
    unawaited(clearDisk());
  }

  static Future<SongCardCache> create(MediaChannel media) async {
    final root = await getApplicationCacheDirectory();
    final directory = Directory('${root.path}/repsound_artwork');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return SongCardCache._(media, directory);
  }

  /// Atualiza a janela conforme o número de itens realmente visíveis.
  /// A capacidade é sempre 4× esse número.
  void setVisibleCount(int count) {
    final clamped = count.clamp(1, 400).toInt();
    final nextCapacity = clamped * 4;
    _visibleCount = clamped;
    if (nextCapacity == _capacity) return;
    _capacity = nextCapacity;
    _trim();
    notifyListeners();
  }

  String artworkPathFor(String songId) =>
      '${_directory.path}/art_${sanitizeFileName(songId)}.jpg';

  Uri artworkUriFor(Song song) => Uri.file(artworkPathFor(song.id));

  String _noneMarkerPathFor(String songId) =>
      '${_directory.path}/none_${sanitizeFileName(songId)}';

  SongCard? peek(String songId) {
    final card = _cards[songId];
    if (card != null) _touch(songId);
    return card;
  }

  Future<SongCard> load(Song song) {
    final cached = _cards[song.id];
    if (cached != null) {
      _memoryHits++;
      _touch(song.id);
      return Future<SongCard>.value(cached);
    }
    final pending = _inflight[song.id];
    if (pending != null) return pending;

    final future = _loadInternal(song);
    _inflight[song.id] = future;
    future.whenComplete(() => _inflight.remove(song.id));
    return future;
  }

  Future<SongCard> _loadInternal(Song song) async {
    Uint8List? artwork;
    final file = File(artworkPathFor(song.id));
    try {
      if (await file.exists()) {
        artwork = await file.readAsBytes();
        _diskHits++;
      } else if (await File(_noneMarkerPathFor(song.id)).exists()) {
        artwork = null;
      } else {
        artwork = await _media.queryArtwork(song, size: _artworkSize);
        _nativeLoads++;
        if (artwork != null && artwork.isNotEmpty) {
          await file.writeAsBytes(artwork, flush: false);
        } else {
          artwork = null;
          await File(_noneMarkerPathFor(song.id)).writeAsString('1');
        }
      }
    } catch (error) {
      debugPrint('Falha ao carregar capa ${song.id}: $error');
      artwork = null;
    }

    final card = SongCard(song: song, artwork: artwork);
    _put(card);
    return card;
  }

  /// Pré-carrega a faixa atual e as próximas (notificação, próxima música).
  void prefetchAround(List<Song> songs, int index, {int radius = 3}) {
    if (songs.isEmpty || index < 0) return;
    final start = math.max(0, index - 1);
    final end = math.min(songs.length - 1, index + radius);
    for (var i = start; i <= end; i++) {
      unawaited(load(songs[i]));
    }
  }

  void _put(SongCard card) {
    final previous = _cards.remove(card.song.id);
    if (previous != null) {
      _bytes -= previous.artwork?.length ?? 0;
      _order.remove(card.song.id);
    }
    _cards[card.song.id] = card;
    _order.add(card.song.id);
    _bytes += card.artwork?.length ?? 0;
    _trim();
    notifyListeners();
  }

  void _touch(String songId) {
    if (!_order.contains(songId)) return;
    _order.remove(songId);
    _order.add(songId);
  }

  void _trim() {
    while (_cards.length > _capacity && _order.isNotEmpty) {
      _evictOldest();
    }
    while (_bytes > _maxBytes && _cards.length > 1 && _order.isNotEmpty) {
      _evictOldest();
    }
  }

  void _evictOldest() {
    final id = _order.removeAt(0);
    final removed = _cards.remove(id);
    _bytes -= removed?.artwork?.length ?? 0;
  }

  void clearMemory() {
    _cards.clear();
    _order.clear();
    _bytes = 0;
    notifyListeners();
  }

  Future<void> clearDisk() async {
    clearMemory();
    try {
      if (await _directory.exists()) {
        await for (final entity in _directory.list()) {
          if (entity is File) {
            try {
              await entity.delete();
            } catch (_) {
              // ignora arquivo em uso
            }
          }
        }
      }
    } catch (error) {
      debugPrint('Falha ao limpar cache de capas: $error');
    }
    _memoryHits = 0;
    _diskHits = 0;
    _nativeLoads = 0;
    notifyListeners();
  }
}
