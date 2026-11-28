import 'dart:async';

import 'package:intl/intl.dart';

/// Remove acentos, pontuação e normaliza espaços para buscas rápidas.
///
/// O resultado é pré-computado uma única vez por música no índice, então a
/// busca em milhares de faixas custa apenas comparações de substring.
String normalizeForSearch(String input) {
  if (input.isEmpty) return '';
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacritics[char] ?? char);
  }
  var text = buffer.toString();
  text = text.replaceAll(_nonAlphanumeric, ' ');
  return text.trim();
}

final RegExp _nonAlphanumeric = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

const Map<String, String> _diacritics = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
  'ă': 'a', 'ą': 'a', 'æ': 'ae',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ĕ': 'e', 'ė': 'e',
  'ę': 'e', 'ě': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'ĭ': 'i', 'į': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o',
  'ŏ': 'o', 'ő': 'o', 'œ': 'oe',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ŭ': 'u', 'ů': 'u',
  'ű': 'u', 'ų': 'u',
  'ç': 'c', 'ć': 'c', 'ĉ': 'c', 'ċ': 'c', 'č': 'c',
  'ñ': 'n', 'ń': 'n', 'ņ': 'n', 'ň': 'n',
  'ý': 'y', 'ÿ': 'y', 'ŷ': 'y',
  'ğ': 'g', 'ĝ': 'g', 'ġ': 'g', 'ģ': 'g',
  'ĥ': 'h', 'ĵ': 'j', 'ĺ': 'l', 'ļ': 'l', 'ľ': 'l', 'ŀ': 'l', 'ł': 'l',
  'ŕ': 'r', 'ŗ': 'r', 'ř': 'r', 'ś': 's', 'ŝ': 's', 'ş': 's', 'š': 's',
  'ţ': 't', 'ť': 't', 'ŧ': 't', 'ź': 'z', 'ż': 'z', 'ž': 'z',
  'ð': 'd', 'þ': 'th', 'ß': 'ss',
};

/// "3:45" ou "1:02:03".
String formatDuration(int milliseconds) {
  if (milliseconds <= 0) return '--:--';
  final duration = Duration(milliseconds: milliseconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String formatTotalDuration(int milliseconds) {
  if (milliseconds <= 0) return '0 min';
  final totalMinutes = (milliseconds / 60000).round();
  if (totalMinutes < 60) return '$totalMinutes min';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes.remainder(60);
  if (hours < 24) return '${hours}h ${minutes.toString().padLeft(2, '0')}min';
  final days = hours ~/ 24;
  return '${days}d ${hours.remainder(24)}h';
}

String formatCount(int value) {
  if (value < 1000) return '$value';
  if (value < 1000000) {
    final thousands = value / 1000;
    return '${_trimDecimal(thousands)} mil';
  }
  final millions = value / 1000000;
  return '${_trimDecimal(millions)} mi';
}

String _trimDecimal(double value) {
  final fixed = value.toStringAsFixed(value >= 100 ? 0 : 1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '—';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var index = 0;
  while (size >= 1024 && index < units.length - 1) {
    size /= 1024;
    index++;
  }
  final decimals = size >= 10 || index == 0 ? 0 : 1;
  final text = size.toStringAsFixed(decimals);
  final trimmed =
      text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  return '$trimmed ${units[index]}';
}

String formatBitrate(int kbps) => kbps <= 0 ? '—' : '$kbps kbps';

String formatDate(int milliseconds) {
  if (milliseconds <= 0) return '—';
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  return DateFormat('dd/MM/yyyy').format(date);
}

String formatDateTime(int milliseconds) {
  if (milliseconds <= 0) return '—';
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  return DateFormat('dd/MM/yyyy HH:mm').format(date);
}

String formatRelativeDay(int milliseconds) {
  if (milliseconds <= 0) return '—';
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = today.difference(target).inDays;
  if (diff == 0) return 'Hoje';
  if (diff == 1) return 'Ontem';
  if (diff < 7) return 'Há $diff dias';
  return formatDate(milliseconds);
}

String sanitizeFileName(String value) {
  final clean = value.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_');
  return clean.isEmpty ? 'repsound' : clean;
}

/// Ação disparada por um toque na capa do player.
enum SeekTapAction { rewind, togglePlay, forward }

/// Divide a capa em três zonas: esquerda (voltar), centro (play/pause) e
/// direita (avançar). As bordas de 38% foram escolhidas para funcionar bem
/// também em telas pequenas de DAPs.
SeekTapAction seekTapAction(double dx, double width) {
  if (width <= 0) return SeekTapAction.togglePlay;
  final ratio = (dx / width).clamp(0.0, 1.0);
  if (ratio < 0.38) return SeekTapAction.rewind;
  if (ratio > 0.62) return SeekTapAction.forward;
  return SeekTapAction.togglePlay;
}

/// Posição final de um avanço/retrocesso, presa entre 0 e a duração.
int seekTargetMs(int positionMs, int deltaSeconds, int durationMs) {
  if (durationMs <= 0) return positionMs;
  return (positionMs + deltaSeconds * 1000).clamp(0, durationMs).toInt();
}

/// Evita disparar buscas a cada tecla.
class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 220)});

  final Duration delay;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}
