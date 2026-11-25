import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/playlist_controller.dart';
import '../../data/search_service.dart';
import '../../state/library_controller.dart';
import '../widgets/app_snack.dart';
import '../widgets/song_artwork.dart';

/// Renomeia uma playlist existente.
Future<void> showRenamePlaylistDialog(
  BuildContext context,
  PlaylistController profile,
  Playlist playlist,
) async {
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) =>
        _RenamePlaylistDialog(initialName: playlist.name),
  );
  final name = result?.trim() ?? '';
  if (name.isEmpty || name == playlist.name) return;
  profile.renamePlaylist(playlist.id, name);
  if (context.mounted) showAppSnack(context, 'Playlist renomeada.');
}

class _RenamePlaylistDialog extends StatefulWidget {
  const _RenamePlaylistDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenamePlaylistDialog> createState() => _RenamePlaylistDialogState();
}

class _RenamePlaylistDialogState extends State<_RenamePlaylistDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Renomear playlist'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Nome da playlist'),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

/// Confirma e remove uma playlist.
Future<void> confirmDeletePlaylist(
  BuildContext context,
  PlaylistController profile,
  Playlist playlist,
) async {
  final confirmed = await confirmAction(
    context,
    title: 'Excluir playlist?',
    message:
        '“${playlist.name}” será removida. As músicas continuam na biblioteca.',
    confirmLabel: 'Excluir',
    destructive: true,
  );
  if (!confirmed) return;
  profile.deletePlaylist(playlist.id);
  if (context.mounted) showAppSnack(context, 'Playlist excluída.');
}

/// Seletor de faixas da biblioteca para adicionar/remover de uma playlist.
Future<void> showAddSongsSheet(
  BuildContext context, {
  required String playlistId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final insets = MediaQuery.viewInsetsOf(sheetContext).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: insets),
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.78,
          child: _AddSongsSheet(playlistId: playlistId),
        ),
      );
    },
  );
}

class _AddSongsSheet extends StatefulWidget {
  const _AddSongsSheet({required this.playlistId});

  final String playlistId;

  @override
  State<_AddSongsSheet> createState() => _AddSongsSheetState();
}

class _AddSongsSheetState extends State<_AddSongsSheet> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final library = context.read<LibraryController>();
    final profile = context.watch<PlaylistController>();
    final playlist = profile.playlistById(widget.playlistId);
    if (playlist == null) {
      return const Center(child: Text('Playlist removida.'));
    }

    final allSongs = library.songs;
    final songs = _query.trim().isEmpty
        ? allSongs
        : SearchService.search(allSongs, _query, SearchField.all, limit: 400);
    final selected = playlist.songIds.toSet();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Adicionar músicas',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${playlist.name} • ${playlist.length} faixa(s)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Concluir'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Filtrar biblioteca',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar',
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(),
        Expanded(
          child: songs.isEmpty
              ? Center(
                  child: Text(
                    'Nenhuma faixa encontrada.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    final contains = selected.contains(song.id);
                    return ListTile(
                      onTap: () {
                        if (contains) {
                          profile.removeSongFromPlaylist(
                            widget.playlistId,
                            song.id,
                          );
                        } else {
                          profile.addSongs(
                            widget.playlistId,
                            <Song>[song],
                          );
                        }
                      },
                      leading: SongArtwork(song: song, size: 44, radius: 10),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Icon(
                        contains
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded,
                        color: contains
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
