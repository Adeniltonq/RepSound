import '../core/utils.dart';
import 'models.dart';

/// Estilo (gênero) criado pelo usuário.
class SongStyle {
  const SongStyle({
    required this.id,
    required this.name,
    required this.colorValue,
  });

  final String id;
  final String name;
  final int colorValue;

  SongStyle copyWith({String? name, int? colorValue}) => SongStyle(
        id: id,
        name: name ?? this.name,
        colorValue: colorValue ?? this.colorValue,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'colorValue': colorValue,
      };

  static SongStyle fromJson(Map<String, dynamic> json) => SongStyle(
        id: json['id']?.toString() ?? 'style',
        name: json['name']?.toString() ?? 'Estilo',
        colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF2F6BFF,
      );
}

/// Onde a atribuição de estilo é aplicada.
enum StyleTarget { song, album, artist }

String albumStyleKey(Song song) =>
    '${normalizeForSearch(song.artist)}|${normalizeForSearch(song.album)}';

String artistStyleKey(Song song) => normalizeForSearch(song.artist);
