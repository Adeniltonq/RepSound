import 'dart:io';

import 'models.dart';

class LyricLine {
  const LyricLine({this.time, required this.text});

  final Duration? time;
  final String text;
}

class Lyrics {
  const Lyrics({required this.lines, required this.synced});

  final List<LyricLine> lines;
  final bool synced;
}

/// Lê letras locais no formato `.lrc` (sincronizado) ou `.txt` (texto).
class LyricsService {
  LyricsService._();

  static final Map<String, Lyrics?> _cache = <String, Lyrics?>{};

  static Future<Lyrics?> load(Song song, {bool refresh = false}) async {
    final path = song.path;
    if (path == null || path.isEmpty) return null;
    if (!refresh && _cache.containsKey(path)) return _cache[path];
    final base = path.contains('.')
        ? path.substring(0, path.lastIndexOf('.'))
        : path;
    for (final extension in <String>['.lrc', '.LRC', '.txt', '.TXT']) {
      final file = File('$base$extension');
      try {
        if (!await file.exists()) continue;
        final raw = await file.readAsString();
        final lyrics = _parse(raw, synced: extension.toLowerCase() == '.lrc');
        if (lyrics.lines.isNotEmpty) {
          _cache[path] = lyrics;
          return lyrics;
        }
      } catch (_) {
        // arquivo ilegível; tenta a próxima extensão
      }
    }
    _cache[path] = null;
    return null;
  }

  static Lyrics _parse(String raw, {required bool synced}) {
    final lines = <LyricLine>[];
    final timestamp = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');
    for (final rawLine in raw.split(RegExp(r'\r?\n'))) {
      final text = rawLine.replaceAll(timestamp, '').trim();
      if (text.isEmpty) continue;
      final matches = timestamp.allMatches(rawLine);
      if (synced && matches.isNotEmpty) {
        for (final match in matches) {
          final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
          final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
          final fraction = match.group(3);
          final millis = fraction == null
              ? 0
              : (int.tryParse(fraction.padRight(3, '0').substring(0, 3)) ?? 0);
          lines.add(
            LyricLine(
              time: Duration(
                minutes: minutes,
                seconds: seconds,
                milliseconds: millis,
              ),
              text: text,
            ),
          );
        }
      } else {
        lines.add(LyricLine(text: text));
      }
    }
    lines.sort((a, b) {
      final left = a.time ?? Duration.zero;
      final right = b.time ?? Duration.zero;
      return left.compareTo(right);
    });
    return Lyrics(lines: lines, synced: synced && lines.any((line) => line.time != null));
  }

  static int activeLine(Lyrics lyrics, Duration position) {
    if (!lyrics.synced) return -1;
    var active = -1;
    for (var index = 0; index < lyrics.lines.length; index++) {
      final time = lyrics.lines[index].time;
      if (time != null && time <= position) {
        active = index;
      } else {
        break;
      }
    }
    return active;
  }
}
