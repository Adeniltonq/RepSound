import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../player/equalizer_presets.dart';
import '../../state/player_controller.dart';

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  List<double>? _gains;
  double? _bass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final player = context.watch<PlayerController>();
    final bands = player.eqBands;
    final hardware = player.hasHardwareEqualizer;

    final sourceGains = <double>[for (final band in bands) band.gain];
    final localGains = _gains != null && _gains!.length == sourceGains.length
        ? _gains!
        : sourceGains;
    final bass = _bass ?? player.bassBoost;
    final qualityAllowsEffects = player.effectsAllowed;
    final enabled = player.eqEnabled && qualityAllowsEffects;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizador'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () {
              setState(() {
                _gains = null;
                _bass = null;
              });
              player.resetEqualizer();
            },
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Restaurar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: <Widget>[
          if (!hardware)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.20),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.info_outline_rounded, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'O equalizador de hardware está disponível no Android. Suas preferências ficam salvas.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!qualityAllowsEffects)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.tertiary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.tertiary.withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.battery_saver_rounded, color: scheme.tertiary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Modo econômico ativo: o equalizador e o reforço de graves ficam desligados. '
                      'Altere em Ajustes → Reprodução.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Card(
            child: SwitchListTile(
              value: player.eqEnabled,
              onChanged: qualityAllowsEffects ? player.setEqEnabled : null,
              secondary: Icon(
                Icons.equalizer_rounded,
                color: enabled ? scheme.primary : scheme.onSurfaceVariant,
              ),
              title: const Text('Equalizador'),
              subtitle: Text(
                !qualityAllowsEffects
                    ? 'Indisponível no modo econômico'
                    : enabled
                        ? 'Efeitos ativos durante a reprodução'
                        : 'Desativado — som original',
              ),
            ),
          ),
          const SizedBox(height: 18),
          _SectionLabel(
            title: 'Presets',
            subtitle: hardware
                ? 'Toque para aplicar uma curva pronta'
                : 'As curvas ficam salvas para quando o hardware estiver disponível',
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                if (player.eqPreset == 'custom')
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Personalizado'),
                      selected: true,
                      avatar: Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: scheme.primary,
                      ),
                      onSelected: (_) {},
                    ),
                  ),
                for (final preset in EqualizerPresets.all)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(preset.name),
                      selected: player.eqPreset == preset.id,
                      onSelected: enabled
                          ? (_) {
                              setState(() => _gains = null);
                              player.applyPreset(preset.id);
                            }
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 16, 10, 12),
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: <Widget>[
                        Text(
                          'Bandas',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${player.eqMinDb.round()} dB … '
                          '${player.eqMaxDb.round()} dB',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 218,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (var index = 0; index < bands.length; index++)
                          Expanded(
                            child: _BandColumn(
                              label: bands[index].label,
                              gain: localGains[index],
                              minDb: player.eqMinDb,
                              maxDb: player.eqMaxDb,
                              enabled: enabled && hardware,
                              onChanged: (value) {
                                setState(() {
                                  final next = List<double>.of(localGains);
                                  next[index] = value;
                                  _gains = next;
                                });
                              },
                              onChangeEnd: (value) {
                                final next = List<double>.of(localGains);
                                next[index] = value;
                                setState(() => _gains = next);
                                player.setCustomGains(next);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.speaker_rounded,
                        size: 20,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Reforço de graves',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${bass.toStringAsFixed(1)} dB',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: bass.clamp(0, 12),
                    min: 0,
                    max: 12,
                    divisions: 24,
                    label: '${bass.toStringAsFixed(1)} dB',
                    onChanged: enabled && hardware
                        ? (value) => setState(() => _bass = value)
                        : null,
                    onChangeEnd: enabled && hardware
                        ? (value) {
                            setState(() => _bass = value);
                            player.setBassBoost(value);
                          }
                        : null,
                  ),
                  Text(
                    'Usa o reforço de volume do Android (loudness enhancer).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BandColumn extends StatelessWidget {
  const _BandColumn({
    required this.label,
    required this.gain,
    required this.minDb,
    required this.maxDb,
    required this.enabled,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final double gain;
  final double minDb;
  final double maxDb;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final value = gain.clamp(minDb, maxDb).toDouble();
    final positive = value >= 0;
    return Column(
      children: <Widget>[
        Text(
          value.toStringAsFixed(value.abs() >= 10 ? 0 : 1),
          style: theme.textTheme.labelSmall?.copyWith(
            color: positive ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontSize: 9,
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 5.5,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 12,
                ),
              ),
              child: Slider(
                value: value,
                min: minDb,
                max: maxDb,
                onChanged: enabled ? onChanged : null,
                onChangeEnd: enabled ? onChangeEnd : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
