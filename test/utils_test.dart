import 'package:flutter_test/flutter_test.dart';
import 'package:repsound/core/utils.dart';

void main() {
  group('normalizeForSearch', () {
    test('remove acentos, caixa e pontuação', () {
      expect(normalizeForSearch('  Água de Beber! '), 'agua de beber');
      expect(normalizeForSearch('Ação & Reação'), 'acao reacao');
      expect(normalizeForSearch('Café—Com—Leite'), 'cafe com leite');
    });

    test('texto vazio continua vazio', () {
      expect(normalizeForSearch(''), '');
      expect(normalizeForSearch('   '), '');
    });
  });

  group('formatDuration', () {
    test('sem duração', () {
      expect(formatDuration(0), '--:--');
      expect(formatDuration(-10), '--:--');
    });

    test('minutos e segundos', () {
      expect(formatDuration(65000), '1:05');
      expect(formatDuration(599000), '9:59');
    });

    test('horas', () {
      expect(formatDuration(3661000), '1:01:01');
    });
  });

  group('formatTotalDuration', () {
    test('minutos', () {
      expect(formatTotalDuration(0), '0 min');
      expect(formatTotalDuration(900000), '15 min');
    });

    test('horas e dias', () {
      expect(formatTotalDuration(3600000), '1h 00min');
      expect(formatTotalDuration(90000000), '1d 1h');
    });
  });

  group('formatCount', () {
    test('escala', () {
      expect(formatCount(999), '999');
      expect(formatCount(1500), '1.5 mil');
      expect(formatCount(1000000), '1 mi');
    });
  });

  group('formatBytes', () {
    test('unidades', () {
      expect(formatBytes(0), '—');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1536), '1.5 KB');
      expect(formatBytes(5 * 1024 * 1024), '5 MB');
    });
  });

  group('sanitizeFileName', () {
    test('troca caracteres inválidos', () {
      expect(sanitizeFileName('a/b:c d'), 'a_b_c_d');
      expect(sanitizeFileName(''), 'repsound');
    });
  });

  group('toque na capa', () {
    test('divide em esquerda, centro e direita', () {
      expect(seekTapAction(10, 100), SeekTapAction.rewind);
      expect(seekTapAction(50, 100), SeekTapAction.togglePlay);
      expect(seekTapAction(90, 100), SeekTapAction.forward);
      expect(seekTapAction(38, 100), SeekTapAction.togglePlay);
      expect(seekTapAction(62, 100), SeekTapAction.togglePlay);
      expect(seekTapAction(10, 0), SeekTapAction.togglePlay);
    });

    test('avanço e retrocesso ficam presos na faixa', () {
      expect(seekTargetMs(5000, 10, 60000), 15000);
      expect(seekTargetMs(5000, -10, 60000), 0);
      expect(seekTargetMs(55000, 10, 60000), 60000);
      expect(seekTargetMs(5000, 10, 0), 5000);
    });
  });
}
