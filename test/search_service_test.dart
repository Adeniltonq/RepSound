import 'package:flutter_test/flutter_test.dart';
import 'package:repsound/data/models.dart';
import 'package:repsound/data/search_service.dart';

Song _song({
  required String id,
  required String title,
  required String artist,
  required String album,
  String folder = 'Música',
  String format = 'MP3',
  int sizeBytes = 4000000,
  int durationMs = 200000,
}) {
  return Song(
    id: id,
    volume: 'external_primary',
    mediaId: int.parse(id.replaceAll(RegExp(r'\D'), '')),
    albumId: 1,
    title: title,
    artist: artist,
    album: album,
    durationMs: durationMs,
    sizeBytes: sizeBytes,
    dateAddedMs: 1700000000000,
    track: 1,
    year: 2020,
    mimeType: 'audio/mpeg',
    format: format,
    path: '/storage/emulated/0/Music/$id.mp3',
    relativePath: 'Music/',
    folder: folder,
    contentUri: 'content://media/external_primary/audio/media/$id',
  );
}

void main() {
  final library = <Song>[
    _song(
      id: '1',
      title: 'Água de Beber',
      artist: 'João Gilberto',
      album: 'Água de Beber',
    ),
    _song(
      id: '2',
      title: 'Aquarela',
      artist: 'Toquinho',
      album: 'Aquarela',
      folder: 'MPB',
    ),
    _song(
      id: '3',
      title: 'Águas de Março',
      artist: 'Elis Regina',
      album: 'Elis',
      folder: 'MPB',
    ),
    _song(
      id: '4',
      title: 'Tempo Perdido',
      artist: 'Legião Urbana',
      album: 'Dois',
      folder: 'Rock',
      format: 'FLAC',
    ),
  ];

  group('SearchService', () {
    test('busca ignora acentos', () {
      final results = SearchService.search(library, 'agua', SearchField.all);
      expect(results.map((song) => song.id), containsAll(<String>['1', '3']));
    });

    test('busca por artista', () {
      final results =
          SearchService.search(library, 'joao', SearchField.artist);
      expect(results.single.id, '1');
    });

    test('campo título não encontra artista', () {
      final results =
          SearchService.search(library, 'joao', SearchField.title);
      expect(results, isEmpty);
    });

    test('busca por pasta', () {
      final results = SearchService.search(library, 'mpb', SearchField.folder);
      expect(results.map((song) => song.id), containsAll(<String>['2', '3']));
      expect(results.length, 2);
    });

    test('múltiplos termos em campos diferentes', () {
      final results = SearchService.search(
        library,
        'legiao rock',
        SearchField.all,
      );
      expect(results.single.id, '4');
    });

    test('título exato aparece primeiro', () {
      final results =
          SearchService.search(library, 'aquarela', SearchField.all);
      expect(results.first.id, '2');
    });

    test('consulta vazia não retorna nada', () {
      expect(SearchService.search(library, '', SearchField.all), isEmpty);
      expect(SearchService.search(library, '   ', SearchField.all), isEmpty);
    });

    test('respeita o limite de resultados', () {
      final results =
          SearchService.search(library, 'a', SearchField.all, limit: 2);
      expect(results.length, 2);
    });
  });
}
