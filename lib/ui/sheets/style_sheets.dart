import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../data/models.dart';
import '../../data/playlist_controller.dart';
import '../../data/style_controller.dart';
import '../../data/style_models.dart';
import '../widgets/app_snack.dart';
import 'song_sheets.dart';

const List<Color> stylePalette = <Color>[
  AppColors.blue,
  AppColors.cyan,
  AppColors.violet,
  AppColors.green,
  AppColors.amber,
  AppColors.rose,
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
  Color(0xFFF97316),
  Color(0xFF64748B),
];

String styleTargetLabel(StyleTarget target) => switch (target) {
      StyleTarget.song => 'Faixa',
      StyleTarget.album => 'Álbum',
      StyleTarget.artist => 'Artista',
    };

/// Cria ou edita um estilo (nome + cor).
Future<void> showStyleEditor(
  BuildContext context,
  StyleController styles, {
  SongStyle? style,
}) async {
  final result = await showDialog<_StyleDraft>(
    context: context,
    builder: (_) => _StyleEditorDialog(style: style),
  );
  if (result == null) return;
  if (style == null) {
    await styles.create(result.name, result.colorValue);
    if (context.mounted) showAppSnack(context, 'Estilo criado.');
  } else {
    styles.update(
      style.id,
      name: result.name,
      colorValue: result.colorValue,
    );
    if (context.mounted) showAppSnack(context, 'Estilo atualizado.');
  }
}

class _StyleDraft {
  const _StyleDraft(this.name, this.colorValue);

  final String name;
  final int colorValue;
}

class _StyleEditorDialog extends StatefulWidget {
  const _StyleEditorDialog({this.style});

  final SongStyle? style;

  @override
  State<_StyleEditorDialog> createState() => _StyleEditorDialogState();
}

class _StyleEditorDialogState extends State<_StyleEditorDialog> {
  late final TextEditingController _controller;
  late int _color;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.style?.name ?? '');
    _color = widget.style?.colorValue ?? stylePalette.first.toARGB32();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(_StyleDraft(name, _color));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.style == null ? 'Novo estilo' : 'Editar estilo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Nome do estilo'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 18),
          Text('Cor', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final color in stylePalette)
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() => _color = color.toARGB32()),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == color.toARGB32()
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: _color == color.toARGB32()
                        ? const Icon(Icons.check_rounded,
                            size: 18, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Salvar')),
      ],
    );
  }
}

/// Aplica estilos a uma ou várias faixas, em faixa/álbum/artista.
Future<void> showApplyStylesSheet(
  BuildContext context, {
  required List<Song> songs,
}) async {
  if (songs.isEmpty) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ApplyStylesSheet(songs: songs),
  );
}

class _ApplyStylesSheet extends StatefulWidget {
  const _ApplyStylesSheet({required this.songs});

  final List<Song> songs;

  @override
  State<_ApplyStylesSheet> createState() => _ApplyStylesSheetState();
}

class _ApplyStylesSheetState extends State<_ApplyStylesSheet> {
  StyleTarget _target = StyleTarget.song;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    final styles = context.read<StyleController>();
    _selected = <String>{...styles.stylesForSong(widget.songs.first)};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final styles = context.watch<StyleController>();
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      widget.songs.length == 1
                          ? 'Estilo de “${widget.songs.first.title}”'
                          : 'Estilo de ${widget.songs.length} faixas',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await showStyleEditor(context, styles);
                    },
                    child: const Text('Novo'),
                  ),
                ],
              ),
            ),
            SegmentedButton<StyleTarget>(
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: <ButtonSegment<StyleTarget>>[
                for (final target in StyleTarget.values)
                  ButtonSegment<StyleTarget>(
                    value: target,
                    label: Text(styleTargetLabel(target)),
                  ),
              ],
              selected: <StyleTarget>{_target},
              onSelectionChanged: (value) =>
                  setState(() => _target = value.first),
            ),
            const SizedBox(height: 4),
            if (_target != StyleTarget.song)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
                child: Text(
                  _target == StyleTarget.album
                      ? 'Aplica a todas as faixas do mesmo álbum e artista.'
                      : 'Aplica a todas as faixas do mesmo artista.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            const Divider(),
            if (styles.styles.isEmpty)
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: <Widget>[
                    Icon(Icons.palette_outlined,
                        size: 40, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 10),
                    const Text('Nenhum estilo criado ainda'),
                    const SizedBox(height: 4),
                    Text(
                      'Crie um estilo para organizar e gerar playlists automáticas.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 8),
                  children: <Widget>[
                    for (final style in styles.styles)
                      CheckboxListTile(
                        value: _selected.contains(style.id),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selected.add(style.id);
                            } else {
                              _selected.remove(style.id);
                            }
                          });
                        },
                        secondary: CircleAvatar(
                          radius: 12,
                          backgroundColor: Color(style.colorValue),
                        ),
                        title: Text(style.name),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(_selected.clear),
                      child: const Text('Limpar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: styles.styles.isEmpty
                          ? null
                          : () {
                              styles.applyStyles(
                                styleIds: _selected,
                                songs: widget.songs,
                                target: _target,
                              );
                              showAppSnack(context, 'Estilos atualizados.');
                              Navigator.of(context).pop();
                            },
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Adiciona várias faixas a uma playlist existente ou nova.
Future<void> showAddSongsToPlaylistSheet(
  BuildContext context, {
  required List<Song> songs,
}) async {
  if (songs.isEmpty) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _BulkPlaylistSheet(songs: songs),
  );
}

class _BulkPlaylistSheet extends StatelessWidget {
  const _BulkPlaylistSheet({required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = context.watch<PlaylistController>();
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Adicionar à playlist',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    '${songs.length} faixa(s) selecionada(s)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.add_rounded, color: scheme.primary),
              ),
              title: const Text('Nova playlist'),
              onTap: () async {
                final playlist = await showCreatePlaylistDialog(
                  context,
                  profile,
                );
                if (playlist == null) return;
                final added = profile.addSongs(playlist.id, songs);
                if (!context.mounted) return;
                showAppSnack(context, '$added faixa(s) adicionada(s).');
                Navigator.of(context).pop();
              },
            ),
            const Divider(),
            if (profile.playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  'Nenhuma playlist ainda.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: profile.playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = profile.playlists[index];
                    return ListTile(
                      leading: Icon(Icons.queue_music_rounded,
                          color: scheme.primary),
                      title: Text(playlist.name),
                      subtitle: Text('${playlist.length} faixa(s)'),
                      trailing: const Icon(Icons.add_rounded),
                      onTap: () {
                        final added = profile.addSongs(playlist.id, songs);
                        showAppSnack(
                          context,
                          added > 0
                              ? '$added faixa(s) adicionada(s) a ${playlist.name}.'
                              : 'As faixas já estavam em ${playlist.name}.',
                        );
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
