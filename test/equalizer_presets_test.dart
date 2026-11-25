import 'package:flutter_test/flutter_test.dart';
import 'package:repsound/player/equalizer_presets.dart';

void main() {
  group('EqualizerPresets', () {
    test('todos os presets têm 10 ganhos', () {
      for (final preset in EqualizerPresets.all) {
        expect(
          preset.gains.length,
          EqualizerPresets.frequencies.length,
          reason: preset.id,
        );
      }
    });

    test('ids são únicos', () {
      final ids = EqualizerPresets.all.map((preset) => preset.id).toSet();
      expect(ids.length, EqualizerPresets.all.length);
    });

    test('byId encontra presets e devolve null para desconhecido', () {
      expect(EqualizerPresets.byId('rock')?.name, 'Rock');
      expect(EqualizerPresets.byId('flat'), same(EqualizerPresets.flat));
      expect(EqualizerPresets.byId('inexistente'), isNull);
    });

    test('plano mantém todos os ganhos em zero', () {
      for (final frequency in EqualizerPresets.frequencies) {
        expect(EqualizerPresets.flat.gainFor(frequency), 0);
      }
    });
  });

  group('EqualizerPreset.gainFor', () {
    const preset = EqualizerPreset(
      id: 'test',
      name: 'Teste',
      gains: <double>[10, 8, 6, 4, 2, 0, -2, -4, -6, -8],
    );

    test('frequências abaixo da primeira usam o primeiro ganho', () {
      expect(preset.gainFor(10), 10);
    });

    test('frequências acima da última usam o último ganho', () {
      expect(preset.gainFor(30000), -8);
    });

    test('frequências exatas devolvem o ganho do ponto', () {
      expect(preset.gainFor(1000), 0);
      expect(preset.gainFor(31), 10);
    });

    test('interpolação logarítmica entre pontos', () {
      // Ponto médio geométrico entre 500 e 1000 Hz: 500 * sqrt(2) ≈ 707,1
      final midpoint = 500 * 1.4142135623730951;
      final gain = preset.gainFor(midpoint);
      expect(gain, closeTo(1, 0.001));
    });

    test('curva é monotônica para ganhos decrescentes', () {
      var previous = preset.gainFor(31);
      for (var frequency = 62.0;
          frequency <= 16000;
          frequency *= 1.25) {
        final current = preset.gainFor(frequency);
        expect(current, lessThanOrEqualTo(previous + 0.0001));
        previous = current;
      }
    });
  });

  group('EqBandInfo', () {
    test('rótulo em Hz para bandas baixas', () {
      expect(const EqBandInfo(centerFrequency: 31, gain: 0).label, '31');
      expect(const EqBandInfo(centerFrequency: 250, gain: 0).label, '250');
    });

    test('rótulo em kHz para bandas altas', () {
      expect(const EqBandInfo(centerFrequency: 1000, gain: 0).label, '1k');
      expect(const EqBandInfo(centerFrequency: 16000, gain: 0).label, '16k');
      expect(
        const EqBandInfo(centerFrequency: 1500, gain: 0).label,
        '1.5k',
      );
    });
  });
}
