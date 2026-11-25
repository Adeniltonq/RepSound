import '../core/utils.dart';

/// Como a biblioteca está ordenada.
enum SortField {
  title,
  artist,
  album,
  dateAdded,
  duration,
  format,
  quality,
  plays,
  folder,
}

extension SortFieldLabels on SortField {
  String get label => switch (this) {
        SortField.title => 'Título',
        SortField.artist => 'Artista',
        SortField.album => 'Álbum',
        SortField.dateAdded => 'Adicionados',
        SortField.duration => 'Duração',
        SortField.format => 'Formato',
        SortField.quality => 'Qualidade',
        SortField.plays => 'Mais ouvidos',
        SortField.folder => 'Pasta',
      };
}

enum ViewMode { list, grid, compact }

extension ViewModeLabels on ViewMode {
  String get label => switch (this) {
        ViewMode.list => 'Lista',
        ViewMode.grid => 'Grade',
        ViewMode.compact => 'Compacta',
      };
}

enum SearchField { all, title, artist, album, folder }

extension SearchFieldLabels on SearchField {
  String get label => switch (this) {
        SearchField.all => 'Tudo',
        SearchField.title => 'Título',
        SearchField.artist => 'Artista',
        SearchField.album => 'Álbum',
        SearchField.folder => 'Pasta',
      };
}

enum SongQualityTier { lossless, high, standard, low }

extension SongQualityTierLabels on SongQualityTier {
  String get label => switch (this) {
        SongQualityTier.lossless => 'Sem perdas',
        SongQualityTier.high => 'Alta',
        SongQualityTier.standard => 'Padrão',
        SongQualityTier.low => 'Baixa',
      };

  String get shortLabel => switch (this) {
        SongQualityTier.lossless => 'Lossless',
        SongQualityTier.high => 'Alta',
        SongQualityTier.standard => 'Padrão',
        SongQualityTier.low => 'Baixa',
      };
}

enum QualityFilter { all, lossless, high, standard, low }

extension QualityFilterLabels on QualityFilter {
  String get label => switch (this) {
        QualityFilter.all => 'Qualidade',
        QualityFilter.lossless => 'Sem perdas',
        QualityFilter.high => 'Alta (256k+)',
        QualityFilter.standard => 'Padrão (128k+)',
        QualityFilter.low => 'Baixa',
      };

  bool matches(Song song) => switch (this) {
        QualityFilter.all => true,
        QualityFilter.lossless => song.quality == SongQualityTier.lossless,
        QualityFilter.high => song.quality == SongQualityTier.high,
        QualityFilter.standard => song.quality == SongQualityTier.standard,
        QualityFilter.low => song.quality == SongQualityTier.low,
      };
}

/// Perfil de reprodução (afeta equalizador, capas e animações).
enum PlaybackQuality { auto, high, saver }

extension PlaybackQualityLabels on PlaybackQuality {
  String get label => switch (this) {
        PlaybackQuality.auto => 'Automática',
        PlaybackQuality.high => 'Alta fidelidade',
        PlaybackQuality.saver => 'Econômica',
      };

  String get description => switch (this) {
        PlaybackQuality.auto =>
          'Equilíbrio entre som, bateria e memória (capas em 320 px).',
        PlaybackQuality.high =>
          'Capas em 512 px, mais pré-carregamento e equalizador ativo.',
        PlaybackQuality.saver =>
          'Menos memória: capas em 192 px, fila de 300 e efeitos desligados.',
      };
}

enum SongCollectionKind { favorites, recent, mostPlayed, recentlyAdded }

extension SongCollectionKindLabels on SongCollectionKind {
  String get label => switch (this) {
        SongCollectionKind.favorites => 'Favoritos',
        SongCollectionKind.recent => 'Ouvidas recentemente',
        SongCollectionKind.mostPlayed => 'Mais ouvidas',
        SongCollectionKind.recentlyAdded => 'Adicionadas recentemente',
      };

  String get description => switch (this) {
        SongCollectionKind.favorites => 'As faixas que você marcou com o coração.',
        SongCollectionKind.recent => 'Retome de onde parou.',
        SongCollectionKind.mostPlayed => 'As que mais tocaram no RepSound.',
        SongCollectionKind.recentlyAdded => 'Novidades da sua biblioteca.',
      };
}

/// Uma faixa da biblioteca local.
///
/// O objeto é imutável e leve: guarda apenas metadados. A capa e os dados
/// pesados ficam em [SongCardCache], carregados sob demanda.
class Song {
  Song({
    required this.id,
    required this.volume,
    required this.mediaId,
    required this.albumId,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.sizeBytes,
    required this.dateAddedMs,
    required this.track,
    required this.year,
    required this.mimeType,
    required this.format,
    required this.path,
    required this.relativePath,
    required this.folder,
    required this.contentUri,
  });

  final String id;
  final String volume;
  final int mediaId;
  final int albumId;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final int sizeBytes;
  final int dateAddedMs;
  final int track;
  final int year;
  final String mimeType;
  final String format;
  final String? path;
  final String relativePath;
  final String folder;
  final String contentUri;

  /// Estimativa de bitrate a partir do tamanho do arquivo (útil para o filtro
  /// de qualidade quando o MediaStore não informa o bitrate).
  late final int bitrateKbps =
      durationMs > 0 ? (sizeBytes * 8 / durationMs).round() : 0;

  late final SongQualityTier quality = _qualityFrom(format, bitrateKbps);

  late final String titleKey = normalizeForSearch(title);
  late final String artistKey = normalizeForSearch(artist);
  late final String albumKey = normalizeForSearch(album);
  late final String folderKey = normalizeForSearch(folder);

  /// Blob usado pela busca global (já normalizado, sem acentos).
  late final String searchKey = normalizeForSearch(
    '$title $artist $album $folder',
  );

  String get durationLabel => formatDuration(durationMs);
  String get subtitle => '$artist • $album';
  String get qualityLabel => quality.shortLabel;

  bool get isLossless => quality == SongQualityTier.lossless;

  static SongQualityTier _qualityFrom(String format, int bitrate) {
    const lossless = {'FLAC', 'WAV', 'ALAC', 'AIFF', 'APE', 'DSF', 'WAVE'};
    if (lossless.contains(format.toUpperCase())) {
      return SongQualityTier.lossless;
    }
    if (bitrate >= 256) return SongQualityTier.high;
    if (bitrate >= 128) return SongQualityTier.standard;
    if (bitrate > 0) return SongQualityTier.low;
    return SongQualityTier.standard;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'volume': volume,
        'mediaId': mediaId,
        'albumId': albumId,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': durationMs,
        'sizeBytes': sizeBytes,
        'dateAddedMs': dateAddedMs,
        'track': track,
        'year': year,
        'mimeType': mimeType,
        'format': format,
        'path': path,
        'relativePath': relativePath,
        'folder': folder,
        'contentUri': contentUri,
      };

  /// Referência leve usada nos backups de perfil.
  Map<String, dynamic> toRefJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': durationMs,
        'path': path,
      };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id'] as String? ?? '',
        volume: json['volume'] as String? ?? 'external_primary',
        mediaId: _asInt(json['mediaId']),
        albumId: _asInt(json['albumId']),
        title: (json['title'] as String?)?.trim().isNotEmpty == true
            ? (json['title'] as String).trim()
            : 'Faixa sem título',
        artist: (json['artist'] as String?)?.trim().isNotEmpty == true
            ? (json['artist'] as String).trim()
            : 'Artista desconhecido',
        album: (json['album'] as String?)?.trim().isNotEmpty == true
            ? (json['album'] as String).trim()
            : 'Álbum desconhecido',
        durationMs: _asInt(json['durationMs']),
        sizeBytes: _asInt(json['sizeBytes']),
        dateAddedMs: _asInt(json['dateAddedMs']),
        track: _asInt(json['track']),
        year: _asInt(json['year']),
        mimeType: json['mimeType'] as String? ?? 'audio/*',
        format: (json['format'] as String? ?? 'AUDIO').toUpperCase(),
        path: json['path'] as String?,
        relativePath: json['relativePath'] as String? ?? '',
        folder: json['folder'] as String? ?? 'Armazenamento interno',
        contentUri: json['contentUri'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) => other is Song && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Song($id, $title — $artist)';
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// Playlist personalizada (ordem preservada).
class Playlist {
  Playlist({
    required this.id,
    required this.name,
    required List<String> songIds,
    required this.createdAtMs,
    required this.updatedAtMs,
  }) : songIds = List<String>.of(songIds);

  final String id;
  final String name;
  final List<String> songIds;
  final int createdAtMs;
  final int updatedAtMs;

  int get length => songIds.length;

  Playlist copyWith({
    String? name,
    List<String>? songIds,
    int? updatedAtMs,
  }) =>
      Playlist(
        id: id,
        name: name ?? this.name,
        songIds: songIds ?? this.songIds,
        createdAtMs: createdAtMs,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'songIds': songIds,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: json['name'] as String? ?? 'Playlist',
        songIds: (json['songIds'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        createdAtMs: _asInt(json['createdAtMs']),
        updatedAtMs: _asInt(json['updatedAtMs']),
      );
}
