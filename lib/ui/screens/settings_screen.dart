import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/localization.dart';
import '../../core/utils.dart';
import '../../data/backup_service.dart';
import '../../data/models.dart';
import '../../data/playlist_controller.dart';
import '../../data/song_card_cache.dart';
import '../../player/equalizer_presets.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../../state/settings_controller.dart';
import '../widgets/app_snack.dart';
import 'customize_bar_screen.dart';
import 'daily_screen.dart';
import 'equalizer_screen.dart';
import 'listening_stats_screen.dart';
import 'styles_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = context.watch<SettingsController>();
    final library = context.watch<LibraryController>();
    final cards = context.watch<SongCardCache>();
    final player = context.watch<PlayerController>();
    final profile = context.read<PlaylistController>();
    final backup = context.read<BackupService>();
    final presetName =
        EqualizerPresets.byId(player.eqPreset)?.name ?? 'Personalizado';

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Ajustes',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Aparência, áudio, biblioteca e backup.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _SettingsGroup(
            title: 'Aparência',
            children: <Widget>[
              _ThemePicker(settings: settings),
              _AccentPicker(settings: settings),
              SwitchListTile(
                value: settings.animations,
                onChanged: settings.setAnimations,
                secondary: const Icon(Icons.animation_rounded),
                title: const Text('Animações'),
                subtitle: const Text('Transições suaves entre telas'),
              ),
            ],
          ),
          _SettingsGroup(
            title: 'Reprodução',
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.high_quality_rounded),
                title: const Text('Qualidade de reprodução'),
                subtitle: Text(
                  '${settings.playbackQuality.label} — '
                  '${settings.playbackQuality.description}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showQualityDialog(context, settings),
              ),
              ListTile(
                leading: const Icon(Icons.equalizer_rounded),
                title: const Text('Equalizador'),
                subtitle: Text(
                  '$presetName • '
                  '${!player.effectsAllowed
                      ? 'pausado no modo econômico'
                      : player.eqEnabled
                          ? 'ativo'
                          : 'desativado'}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EqualizerScreen(),
                  ),
                ),
              ),
              SwitchListTile(
                value: settings.tapToSeek,
                onChanged: settings.setTapToSeek,
                secondary: const Icon(Icons.touch_app_rounded),
                title: const Text('Toque na capa para avançar/retroceder'),
                subtitle: const Text(
                  'Esquerda volta, direita avança e o centro pausa/retoma.',
                ),
              ),
              if (settings.tapToSeek)
                ListTile(
                  leading: const Icon(Icons.timelapse_rounded),
                  title: const Text('Passo do toque'),
                  subtitle: Text(
                    '${settings.seekStepSeconds} segundos por toque',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showSeekStepDialog(context, settings),
                ),
              _SliderTile(
                title: 'Ignorar faixas curtas',
                subtitle:
                    'Aplicado na próxima varredura da biblioteca.',
                value: settings.minDurationSec.toDouble(),
                min: 0,
                max: 120,
                divisions: 24,
                valueLabel: '${settings.minDurationSec}s',
                onChanged: (value) =>
                    settings.setMinDurationSec(value.round()),
              ),
            ],
          ),
          _SettingsGroup(
            title: 'Biblioteca',
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Atualizar biblioteca'),
                subtitle: Text(
                  '${library.totalSongs} faixa(s) • '
                  '${library.isScanning ? 'escaneando...' : 'armazenamento do aparelho'}',
                ),
                trailing: library.isScanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right_rounded),
                onTap: library.isScanning
                    ? null
                    : () async {
                        final ok = await library.scan();
                        if (!context.mounted) return;
                        showAppSnack(
                          context,
                          ok
                              ? 'Biblioteca atualizada: ${library.totalSongs} faixas.'
                              : (library.error ??
                                  'Não foi possível atualizar agora.'),
                        );
                      },
              ),
              ListTile(
                leading: const Icon(Icons.storage_rounded),
                title: const Text('Índice salvo em arquivo'),
                subtitle: FutureBuilder<int>(
                  future: library.indexSizeBytes(),
                  builder: (context, snapshot) {
                    final size = snapshot.data;
                    final updated = library.lastScanMs > 0
                        ? formatRelativeDay(library.lastScanMs)
                        : 'nunca';
                    return Text(
                      '${size == null ? '…' : formatBytes(size)} • '
                      '${library.totalSongs} faixas\nÚltima varredura: $updated',
                    );
                  },
                ),
                isThreeLine: true,
              ),
              ListTile(
                leading: const Icon(Icons.image_rounded),
                title: const Text('Cache de capas'),
                subtitle: Text(
                  '${cards.loadedCards} de ${cards.capacity} fichas em memória • '
                  '${formatBytes(cards.memoryBytes)}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final confirmed = await confirmAction(
                    context,
                    title: 'Limpar cache de capas?',
                    message:
                        'As capas serão baixadas novamente conforme você navegar. '
                        'A biblioteca e as playlists não são afetadas.',
                    confirmLabel: 'Limpar',
                  );
                  if (!confirmed) return;
                  await cards.clearDisk();
                  if (context.mounted) {
                    showAppSnack(context, 'Cache de capas limpo.');
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_sweep_rounded, color: scheme.error),
                title: Text(
                  'Apagar índice da biblioteca',
                  style: TextStyle(color: scheme.error),
                ),
                subtitle: const Text(
                  'A próxima abertura exigirá uma nova varredura.',
                ),
                onTap: () async {
                  final confirmed = await confirmAction(
                    context,
                    title: 'Apagar índice?',
                    message:
                        'O arquivo library_index.json será removido. Suas playlists e favoritos continuam salvos.',
                    confirmLabel: 'Apagar',
                    destructive: true,
                  );
                  if (!confirmed) return;
                  await library.clearIndex();
                  if (context.mounted) {
                    showAppSnack(context, 'Índice apagado.');
                  }
                },
              ),
            ],
          ),
          _SettingsGroup(
            title: 'Backup e perfil',
            children: <Widget>[
              SwitchListTile(
                value: settings.autoBackup,
                onChanged: settings.setAutoBackup,
                secondary: const Icon(Icons.cloud_sync_rounded),
                title: const Text('Backup automático local'),
                subtitle: const Text(
                  'Salva um JSON alguns segundos após cada mudança.',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.data_object_rounded),
                title: const Text('Exportar perfil em JSON'),
                subtitle: const Text(
                  'Playlists, favoritos, estatísticas e ajustes',
                ),
                trailing: const Icon(Icons.ios_share_rounded),
                onTap: () => _export(context, backup, json: true),
              ),
              ListTile(
                leading: const Icon(Icons.table_chart_rounded),
                title: const Text('Exportar perfil em CSV'),
                subtitle: const Text(
                  'Abre em planilhas e editores de texto',
                ),
                trailing: const Icon(Icons.ios_share_rounded),
                onTap: () => _export(context, backup, json: false),
              ),
              ListTile(
                leading: const Icon(Icons.file_open_rounded),
                title: const Text('Importar perfil'),
                subtitle: Text(
                  'Último backup: ${settings.lastBackupMs > 0 ? formatDateTime(settings.lastBackupMs) : 'nunca'}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _import(context, backup),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.lock_outline_rounded, color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sem login. O arquivo é compartilhado pelo menu do sistema — salve no Drive, Nextcloud, Dropbox ou onde preferir.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _SettingsGroup(
            title: 'Dados de escuta',
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.history_toggle_off_rounded),
                title: const Text('Limpar histórico'),
                subtitle: Text('${profile.history.length} faixa(s) recentes'),
                onTap: () async {
                  final confirmed = await confirmAction(
                    context,
                    title: 'Limpar histórico?',
                    message:
                        'As faixas recentes deixam de aparecer, mas os contadores de reprodução continuam.',
                    confirmLabel: 'Limpar',
                  );
                  if (!confirmed) return;
                  profile.clearHistory();
                  if (context.mounted) {
                    showAppSnack(context, 'Histórico limpo.');
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.restart_alt_rounded, color: scheme.error),
                title: Text(
                  'Zerar estatísticas',
                  style: TextStyle(color: scheme.error),
                ),
                subtitle: const Text(
                  'Apaga reproduções, histórico e últimas execuções.',
                ),
                onTap: () async {
                  final confirmed = await confirmAction(
                    context,
                    title: 'Zerar estatísticas?',
                    message:
                        'Os contadores de “mais ouvidas” e o histórico serão apagados.',
                    confirmLabel: 'Zerar',
                    destructive: true,
                  );
                  if (!confirmed) return;
                  profile.resetStatistics();
                  if (context.mounted) {
                    showAppSnack(context, 'Estatísticas zeradas.');
                  }
                },
              ),
            ],
          ),
          _SettingsGroup(
            title: 'Personalização',
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.palette_rounded),
                title: const Text('Estilos'),
                subtitle: const Text(
                  'Crie estilos e gere playlists automáticas por estilo',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const StylesScreen(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.today_rounded),
                title: const Text('Daily'),
                subtitle: const Text(
                  'Estilos da seleção do dia e atualização automática',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DailyScreen(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.insights_rounded),
                title: const Text('Estatísticas de escuta'),
                subtitle: const Text(
                  'Histórico, última reprodução, pulos e % média ouvida',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ListeningStatsScreen(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.view_sidebar_rounded),
                title: const Text('Barra inferior'),
                subtitle: Text(
                  'Ordem e aba inicial • ${settings.tabOrder.length} abas',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CustomizeBarScreen(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.translate_rounded),
                title: const Text('Idioma'),
                subtitle: Text(
                  appLanguages
                      .firstWhere(
                        (language) => language.code == settings.localeCode,
                        orElse: () => appLanguages.first,
                      )
                      .nativeName,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showLanguageDialog(context, settings),
              ),
            ],
          ),
          _SettingsGroup(
            title: 'Sobre',
            children: <Widget>[
              const ListTile(
                leading: Icon(Icons.music_note_rounded),
                title: Text('RepSound'),
                subtitle: Text('Versão 1.0.0 • Flutter'),
              ),
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Privacidade'),
                subtitle: const Text(
                  'Tudo fica no seu aparelho. Nenhuma conta é necessária.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> _showLanguageDialog(
    BuildContext context,
    SettingsController settings,
  ) async {
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Idioma'),
        children: <Widget>[
          for (final language in appLanguages)
            ListTile(
              title: Text(language.nativeName),
              trailing: language.code == settings.localeCode
                  ? Icon(
                      Icons.check_rounded,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    )
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(language.code),
            ),
        ],
      ),
    );
    if (code == null) return;
    settings.setLocale(code);
  }

  static Future<void> _export(
    BuildContext context,
    BackupService backup, {
    required bool json,
  }) async {
    try {
      if (json) {
        await backup.shareJson();
      } else {
        await backup.shareCsv();
      }
      if (context.mounted) {
        showAppSnack(
          context,
          json
              ? 'Perfil exportado em JSON.'
              : 'Perfil exportado em CSV.',
        );
      }
    } catch (error) {
      if (context.mounted) {
        showAppSnack(context, 'Não foi possível exportar: $error');
      }
    }
  }

  static Future<void> _import(
    BuildContext context,
    BackupService backup,
  ) async {
    final mode = await showDialog<ImportMode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Importar perfil'),
        content: const Text(
          'Escolha como aplicar o arquivo JSON ou CSV escolhido.\n\n'
          'Mesclar mantém o que já existe e soma as faixas. '
          'Substituir troca playlists, favoritos e estatísticas.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(ImportMode.merge),
            child: const Text('Mesclar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(ImportMode.replace),
            child: const Text('Substituir'),
          ),
        ],
      ),
    );
    if (mode == null) return;
    try {
      final result = await backup.pickAndImport(mode: mode);
      if (result == null) return;
      if (context.mounted) showAppSnack(context, result.message);
    } on BackupException catch (error) {
      if (context.mounted) showAppSnack(context, error.message);
    } catch (error) {
      if (context.mounted) {
        showAppSnack(context, 'Falha ao importar: $error');
      }
    }
  }

  static Future<void> _showSeekStepDialog(
    BuildContext context,
    SettingsController settings,
  ) async {
    const options = <int>[5, 10, 15, 30, 60];
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Passo do toque'),
        children: <Widget>[
          for (final seconds in options)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(seconds),
              child: Row(
                children: <Widget>[
                  Icon(
                    seconds == settings.seekStepSeconds
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 20,
                    color: seconds == settings.seekStepSeconds
                        ? Theme.of(dialogContext).colorScheme.primary
                        : Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Text('$seconds segundos'),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected != null) settings.setSeekStepSeconds(selected);
  }

  static Future<void> _showQualityDialog(
    BuildContext context,
    SettingsController settings,
  ) async {
    final selected = await showDialog<PlaybackQuality>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final scheme = theme.colorScheme;
        return SimpleDialog(
          title: const Text('Qualidade de reprodução'),
          children: <Widget>[
            for (final quality in PlaybackQuality.values)
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(quality),
                child: Row(
                  children: <Widget>[
                    Icon(
                      quality == settings.playbackQuality
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: quality == settings.playbackQuality
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            quality.label,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            quality.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
    if (selected != null) settings.setPlaybackQuality(selected);
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                for (var index = 0; index < children.length; index++) ...<Widget>[
                  if (index > 0)
                    Divider(
                      height: 1,
                      indent: 16,
                      color: scheme.outlineVariant,
                    ),
                  children[index],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Tema',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<ThemeMode>>[
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_rounded),
                label: Text('Escuro'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_rounded),
                label: Text('Claro'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_rounded),
                label: Text('Sistema'),
              ),
            ],
            selected: <ThemeMode>{settings.themeMode},
            onSelectionChanged: (selection) =>
                settings.setThemeMode(selection.first),
          ),
        ],
      ),
    );
  }
}

class _AccentPicker extends StatelessWidget {
  const _AccentPicker({required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Cor de destaque',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: <Widget>[
              for (var index = 0; index < AppColors.accents.length; index++)
                _AccentDot(
                  color: AppColors.accents[index],
                  selected: settings.accentIndex == index,
                  label: AppColors.accentNames[index],
                  onTap: () => settings.setAccentIndex(index),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'O tema escuro usa preto profundo para economizar bateria em telas OLED.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({
    required this.color,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.onSurface : Colors.transparent,
              width: 2.4,
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: selected
              ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                valueLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
