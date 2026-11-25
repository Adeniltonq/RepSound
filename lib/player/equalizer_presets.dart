import 'dart:math' as math;

/// Presets de equalização de 10 bandas.
class EqualizerPreset {
  const EqualizerPreset({
    required this.id,
    required this.name,
    required this.gains,
  });

  final String id;
  final String name;

  /// Ganhos em dB nas frequências de referência.
  final List<double> gains;

  /// Interpola o ganho para a frequência real de uma banda do aparelho.
  double gainFor(double frequency) {
    final anchors = EqualizerPresets.frequencies;
    if (frequency <= anchors.first) return gains.first;
    if (frequency >= anchors.last) return gains.last;
    for (var index = 0; index < anchors.length - 1; index++) {
      final low = anchors[index];
      final high = anchors[index + 1];
      if (frequency >= low && frequency <= high) {
        final t = (math.log(frequency) - math.log(low)) /
            (math.log(high) - math.log(low));
        return gains[index] + (gains[index + 1] - gains[index]) * t;
      }
    }
    return 0;
  }
}

abstract final class EqualizerPresets {
  static const List<double> frequencies = <double>[
    31,
    62,
    125,
    250,
    500,
    1000,
    2000,
    4000,
    8000,
    16000,
  ];

  static const EqualizerPreset flat = EqualizerPreset(
    id: 'flat',
    name: 'Plano',
    gains: <double>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  );

  static const List<EqualizerPreset> all = <EqualizerPreset>[
    flat,
    EqualizerPreset(
      id: 'bass',
      name: 'Graves',
      gains: <double>[7, 6, 4, 2, 0, -1, -1, -1, -2, -2],
    ),
    EqualizerPreset(
      id: 'vocal',
      name: 'Voz',
      gains: <double>[-2, -1, 0, 2, 4, 4, 3, 1, 0, -1],
    ),
    EqualizerPreset(
      id: 'rock',
      name: 'Rock',
      gains: <double>[5, 4, 2, -1, -2, 0, 2, 3, 4, 3],
    ),
    EqualizerPreset(
      id: 'pop',
      name: 'Pop',
      gains: <double>[-1, 0, 2, 3, 2, 0, -1, -1, 0, 1],
    ),
    EqualizerPreset(
      id: 'electronic',
      name: 'Eletrônico',
      gains: <double>[6, 5, 2, 0, -1, 1, 2, 4, 5, 4],
    ),
    EqualizerPreset(
      id: 'jazz',
      name: 'Jazz',
      gains: <double>[3, 2, 1, 2, -1, -1, 0, 1, 2, 3],
    ),
    EqualizerPreset(
      id: 'classical',
      name: 'Clássico',
      gains: <double>[4, 3, 2, 1, 0, 0, -1, -1, -2, -3],
    ),
    EqualizerPreset(
      id: 'treble',
      name: 'Agudos',
      gains: <double>[-2, -1, 0, 0, 0, 1, 3, 4, 5, 5],
    ),
  ];

  static EqualizerPreset? byId(String id) {
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return null;
  }
}

class EqBandInfo {
  const EqBandInfo({required this.centerFrequency, required this.gain});

  final double centerFrequency;
  final double gain;

  String get label {
    if (centerFrequency >= 1000) {
      final value = centerFrequency / 1000;
      return '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)}k';
    }
    return centerFrequency.round().toString();
  }
}
