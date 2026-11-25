import 'package:flutter_test/flutter_test.dart';
import 'package:repsound/data/models.dart';
import 'package:repsound/state/playback_queue.dart';

Song _song(String id) => Song(
      id: id,
      volume: 'external',
      mediaId: int.parse(id),
      albumId: 1,
      title: 'Faixa $id',
      artist: 'Artista',
      album: 'Álbum',
      durationMs: 180000,
      sizeBytes: 4000000,
      dateAddedMs: 0,
      track: int.parse(id),
      year: 2024,
      mimeType: 'audio/mpeg',
      format: 'MP3',
      path: '/music/$id.mp3',
      relativePath: 'music/$id.mp3',
      folder: 'Music',
      contentUri: 'content://media/$id',
    );

void main() {
  group('PlaybackQueue', () {
    test('começa no contexto e na faixa clicada', () {
      final queue = PlaybackQueue(
        contextSongs: <Song>[_song('1'), _song('2'), _song('3')],
        originLabel: 'Biblioteca',
        initialIndex: 1,
      );

      expect(queue.songs.map((song) => song.id), <String>['1', '2', '3']);
      expect(queue.currentSong?.id, '2');
      expect(queue.isEdited, isFalse);
    });

    test('adiciona faixas manuais antes do restante do contexto', () {
      final queue = PlaybackQueue(
        contextSongs: <Song>[_song('1'), _song('2'), _song('3')],
        originLabel: 'Biblioteca',
      );

      expect(queue.addToQueue(_song('9')), 1);
      expect(queue.addToQueue(_song('8')), 2);
      expect(queue.addNext(_song('7')), 1);
      expect(
        queue.songs.map((song) => song.id),
        <String>['1', '7', '9', '8', '2', '3'],
      );
      expect(queue.isEdited, isTrue);
    });

    test('remove pendentes e mantém a faixa atual', () {
      final queue = PlaybackQueue(
        contextSongs: <Song>[_song('1'), _song('2'), _song('3')],
        originLabel: 'Biblioteca',
        initialIndex: 1,
      );

      expect(queue.removeAt(1), isFalse);
      expect(queue.removeAt(2), isTrue);
      expect(queue.songs.map((song) => song.id), <String>['1', '2']);
      expect(queue.currentSong?.id, '2');
      expect(queue.currentIndex, 1);
    });

    test('reordenar mantém o índice da faixa atual', () {
      final queue = PlaybackQueue(
        contextSongs: <Song>[_song('1'), _song('2'), _song('3')],
        originLabel: 'Biblioteca',
        initialIndex: 1,
      );

      queue.move(0, 2);
      expect(queue.songs.map((song) => song.id), <String>['2', '3', '1']);
      expect(queue.currentSong?.id, '2');
      expect(queue.currentIndex, 0);
    });

    test('limpar mantém só a faixa atual', () {
      final queue = PlaybackQueue(
        contextSongs: <Song>[_song('1'), _song('2'), _song('3')],
        originLabel: 'Biblioteca',
        initialIndex: 1,
      );

      queue.addNext(_song('9'));
      queue.clearPending();
      expect(queue.songs.map((song) => song.id), <String>['2']);
      expect(queue.currentIndex, 0);
    });

    test('restaurar reconstrói o contexto e mantém a faixa atual', () {
      final queue = PlaybackQueue(
        contextSongs: <Song>[_song('1'), _song('2'), _song('3')],
        originLabel: 'Biblioteca',
        initialIndex: 1,
      );

      queue.addNext(_song('9'));
      queue.move(1, 3);
      queue.restoreContext();

      expect(queue.songs.map((song) => song.id), <String>['1', '2', '3']);
      expect(queue.currentSong?.id, '2');
      expect(queue.currentIndex, 1);
      expect(queue.isEdited, isFalse);
    });

    test('JSON preserva edições e a faixa atual', () {
      final queue = PlaybackQueue(
        contextSongs: <Song>[_song('1'), _song('2'), _song('3')],
        originLabel: 'Pesquisa “Sleep Token”',
        initialIndex: 1,
      );
      queue.addNext(_song('9'));

      final json = queue.toJson(positionMs: 4200);
      final restored = PlaybackQueue.fromJson(
        json,
        (id) => <String, Song>{
          '1': _song('1'),
          '2': _song('2'),
          '3': _song('3'),
          '9': _song('9'),
        }[id],
      );

      expect(restored, isNotNull);
      expect(restored!.originLabel, 'Pesquisa “Sleep Token”');
      expect(restored.songs.map((song) => song.id), <String>['1', '2', '9', '3']);
      expect(restored.entries[2].manual, isTrue);
      expect(restored.currentSong?.id, '2');
      expect(restored.currentIndex, 1);
    });
  });
}
