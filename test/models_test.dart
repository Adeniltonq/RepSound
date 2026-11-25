import 'package:flutter_test/flutter_test.dart';
import 'package:repsound/data/models.dart';

Song buildSong({
  String id = '42',
  String title = 'Águas de Março',
  String artist = 'Elis Regina',
  String album = 'Elis',
  String format = 'MP3',
  int durationMs = 200000,
  int sizeBytes = 4000000,
}) {
  return Song(
    id: id,
    volume: 'external_primary',
    mediaId: 42,
    albumId: 7,
    title: title,
    artist: artist,
    album: album,
    durationMs: durationMs,
    sizeBytes: sizeBytes,
    dateAddedMs: 1700000000000,
    track: 3,
    year: 1974,
    mimeType: 'audio/mpeg',
    format: format,
    path: '/storage/emulated/0/Music/elis/03.mp3',
    relativePath: 'Music/elis/',
    folder: 'Music/elis',
    contentUri: 'content://media/external_primary/audio/media/42',
  );
}

void main() {
  group('Song', () {
    test('ida e volta pelo JSON preserva os campos', () {
      final song = buildSong();
      final restored = Song.fromJson(song.toJson());

      expect(restored.id, song.id);
      expect(restored.volume, song.volume);
      expect(restored.mediaId, song.mediaId);
      expect(restored.albumId, song.albumId);
      expect(restored.title, song.title);
      expect(restored.artist, song.artist);
      expect(restored.album, song.album);
      expect(restored.durationMs, song.durationMs);
      expect(restored.sizeBytes, song.sizeBytes);
      expect(restored.dateAddedMs, song.dateAddedMs);
      expect(restored.track, song.track);
      expect(restored.year, song.year);
      expect(restored.mimeType, song.mimeType);
      expect(restored.format, song.format);
      expect(restored.path, song.path);
      expect(restored.relativePath, song.relativePath);
      expect(restored.folder, song.folder);
      expect(restored.contentUri, song.contentUri);
    });

    test('JSON aceita números como texto', () {
      final json = buildSong().toJson()
        ..['mediaId'] = '99'
        ..['durationMs'] = '123456'
        ..['sizeBytes'] = 789.0;

      final restored = Song.fromJson(json);

      expect(restored.mediaId, 99);
      expect(restored.durationMs, 123456);
      expect(restored.sizeBytes, 789);
    });

    test('JSON incompleto cai nos padrões', () {
      final restored = Song.fromJson(<String, dynamic>{'id': 'x'});

      expect(restored.id, 'x');
      expect(restored.title, 'Faixa sem título');
      expect(restored.artist, 'Artista desconhecido');
      expect(restored.album, 'Álbum desconhecido');
      expect(restored.format, 'AUDIO');
      expect(restored.folder, 'Armazenamento interno');
      expect(restored.durationMs, 0);
    });

    test('bitrate é estimado pelo tamanho e duração', () {
      final song = buildSong(durationMs: 200000, sizeBytes: 4000000);
      // 4.000.000 bytes * 8 / 200.000 ms = 160 kbps
      expect(song.bitrateKbps, 160);
    });

    test('duração zero não gera bitrate', () {
      final song = buildSong(durationMs: 0, sizeBytes: 4000000);
      expect(song.bitrateKbps, 0);
    });

    test('qualidade considera formato e bitrate', () {
      expect(buildSong(format: 'FLAC').quality, SongQualityTier.lossless);
      expect(buildSong(format: 'flac').quality, SongQualityTier.lossless);
      expect(buildSong(format: 'WAV').quality, SongQualityTier.lossless);
      expect(
        buildSong(format: 'MP3', durationMs: 200000, sizeBytes: 8000000).quality,
        SongQualityTier.high,
      );
      expect(
        buildSong(format: 'MP3', durationMs: 200000, sizeBytes: 4000000).quality,
        SongQualityTier.standard,
      );
      expect(
        buildSong(format: 'MP3', durationMs: 200000, sizeBytes: 2000000).quality,
        SongQualityTier.low,
      );
    });

    test('chaves de busca ignoram acentos e caixa', () {
      final song = buildSong();
      expect(song.titleKey, 'aguas de marco');
      expect(song.artistKey, 'elis regina');
      expect(song.searchKey, contains('aguas de marco'));
      expect(song.searchKey, contains('music elis'));
    });

    test('rótulos de duração e subtítulo', () {
      final song = buildSong(durationMs: 185000);
      expect(song.durationLabel, '3:05');
      expect(song.subtitle, 'Elis Regina • Elis');
    });

    test('igualdade e hash são baseados no id', () {
      final a = buildSong(id: '1', title: 'A');
      final b = buildSong(id: '1', title: 'B');
      final c = buildSong(id: '2');

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });

  group('Playlist', () {
    test('ida e volta pelo JSON preserva a ordem', () {
      final playlist = Playlist(
        id: 'p1',
        name: 'Viagem',
        songIds: <String>['3', '1', '2'],
        createdAtMs: 1000,
        updatedAtMs: 2000,
      );

      final restored = Playlist.fromJson(playlist.toJson());

      expect(restored.id, 'p1');
      expect(restored.name, 'Viagem');
      expect(restored.songIds, <String>['3', '1', '2']);
      expect(restored.createdAtMs, 1000);
      expect(restored.updatedAtMs, 2000);
      expect(restored.length, 3);
    });

    test('cópia defensiva da lista de ids', () {
      final ids = <String>['1'];
      final playlist = Playlist(
        id: 'p1',
        name: 'Teste',
        songIds: ids,
        createdAtMs: 0,
        updatedAtMs: 0,
      );
      ids.add('2');
      expect(playlist.songIds, <String>['1']);
    });

    test('copyWith troca apenas o informado', () {
      final playlist = Playlist(
        id: 'p1',
        name: 'Antiga',
        songIds: <String>['1', '2'],
        createdAtMs: 10,
        updatedAtMs: 20,
      );

      final renamed = playlist.copyWith(name: 'Nova', updatedAtMs: 30);

      expect(renamed.id, 'p1');
      expect(renamed.name, 'Nova');
      expect(renamed.songIds, <String>['1', '2']);
      expect(renamed.createdAtMs, 10);
      expect(renamed.updatedAtMs, 30);
    });

    test('JSON incompleto usa padrões', () {
      final restored = Playlist.fromJson(<String, dynamic>{});
      expect(restored.name, 'Playlist');
      expect(restored.songIds, isEmpty);
      expect(restored.id, isNotEmpty);
    });
  });

  group('enums', () {
    test('rótulos de ordenação existem', () {
      for (final field in SortField.values) {
        expect(field.label, isNotEmpty);
      }
    });

    test('filtro de qualidade casa com o nível da faixa', () {
      final lossless = buildSong(format: 'FLAC');
      final high = buildSong(
        format: 'MP3',
        durationMs: 200000,
        sizeBytes: 8000000,
      );

      expect(QualityFilter.lossless.matches(lossless), isTrue);
      expect(QualityFilter.lossless.matches(high), isFalse);
      expect(QualityFilter.high.matches(high), isTrue);
      expect(QualityFilter.all.matches(lossless), isTrue);
    });
  });
}
