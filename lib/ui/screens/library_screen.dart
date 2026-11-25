import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils.dart';
import '../../data/models.dart';
import '../../data/search_service.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../../state/settings_controller.dart';
import '../widgets/app_snack.dart';
import '../widgets/common.dart';
import '../widgets/song_list_view.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => LibraryScreenState();
}

class LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final Debouncer _debouncer = Debouncer(
    delay: const Duration(milliseconds: 200),
  );

  SearchField _field = SearchField.all;
  List<Song> _results = const <Song>[];
  String _query = '';
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onTextChanged);
    _searchFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _searchController
      ..removeListener(_onTextChanged)
      ..dispose();
    _searchFocus
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  /// Foca o campo de busca (atalho da tela inicial).
  void focusSearch() {
    if (!mounted) return;
    _searchFocus.requestFocus();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _onTextChanged() {
    if (!mounted) return;
    setState(() => _searching = true);
    _debouncer.run(() => _run(_searchController.text));
  }

  void _run(String raw) {
    if (!mounted) return;
    final query = raw.trim();
    final library = context.read<LibraryController>();
    final results = query.isEmpty
        ? const <Song>[]
        : SearchService.search(library.songs, query, _field);
    setState(() {
      _query = query;
      _results = results;
      _searching = false;
    });
  }

  void _submit(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    context.read<SettingsController>().addRecentSearch(text);
    _searchFocus.unfocus();
    _debouncer.cancel();
    _run(text);
  }

  void _applyRecent(String value) {
    _searchController.text = value;
    _searchController.selection = TextSelection.collapsed(offset: value.length);
    _searchFocus.unfocus();
    _debouncer.cancel();
    _run(value);
  }

  void _clearSearch() {
    _searchController.clear();
    _debouncer.cancel();
    _searchFocus.unfocus();
    _run('');
  }

  void _changeField(SearchField field) {
    if (_field == field) return;
    setState(() => _field = field);
    _debouncer.cancel();
    _run(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final settings = context.watch<SettingsController>();
    final player = context.read<PlayerController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final searching = _query.isNotEmpty;
    final songs = searching ? _results : library.filteredSongs;

    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 6, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Biblioteca',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        searching
                            ? '${_results.length} resultado(s) para “$_query”'
                            : '${songs.length} de ${library.totalSongs} faixas • '
                                '${formatTotalDuration(library.totalDurationMs)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Filtros',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showFilters(context),
                  icon: Badge(
                    isLabelVisible: library.hasActiveFilters,
                    child: const Icon(Icons.tune_rounded),
                  ),
                ),
                IconButton(
                  tooltip: 'Ordenar (${library.sortField.label})',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showSort(context),
                  icon: const Icon(Icons.sort_rounded),
                ),
                IconButton(
                  tooltip: 'Visualização',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showView(context),
                  icon: Icon(
                    switch (settings.viewMode) {
                      ViewMode.list => Icons.view_agenda_outlined,
                      ViewMode.grid => Icons.grid_view_rounded,
                      ViewMode.compact => Icons.view_headline_rounded,
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Atualizar biblioteca',
                  visualDensity: VisualDensity.compact,
                  onPressed: library.isScanning
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
                  icon: library.isScanning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
              decoration: InputDecoration(
                hintText: 'Buscar música, artista ou pasta',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar busca',
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          if (_searching)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 6, 18, 0),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (searching)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                itemCount: SearchField.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final field = SearchField.values[index];
                  return ChoiceChip(
                    label: Text(field.label),
                    selected: _field == field,
                    onSelected: (_) => _changeField(field),
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
          if (!searching && _searchFocus.hasFocus)
            _RecentSearchRow(
              searches: settings.recentSearches,
              onSelect: _applyRecent,
              onClear: settings.clearRecentSearches,
            ),
          if (library.isScanning)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (!searching && library.hasActiveFilters)
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                children: <Widget>[
                  for (final format in library.formatFilters)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        label: Text(format),
                        onDeleted: () => library.toggleFormat(format),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  if (library.qualityFilter != QualityFilter.all)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        label: Text(library.qualityFilter.label),
                        onDeleted: () =>
                            library.setQualityFilter(QualityFilter.all),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  if (library.folderFilter != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        avatar: const Icon(Icons.folder_rounded, size: 15),
                        label: Text(library.folderFilter!),
                        onDeleted: () => library.setFolderFilter(null),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  TextButton(
                    onPressed: library.clearFilters,
                    child: const Text('Limpar'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: library.totalSongs == 0
                ? EmptyState(
                    icon: Icons.library_music_rounded,
                    title: 'Biblioteca vazia',
                    message: !library.supported
                        ? 'A leitura automática da biblioteca está disponível no Android.'
                        : library.permissionBlocked
                            ? 'O acesso às músicas foi negado. Abra os ajustes do sistema e permita “Música e áudio” para o RepSound.'
                            : 'Toque em escanear para ler o armazenamento interno e o cartão microSD.',
                    actionLabel: library.isScanning
                        ? 'Escaneando...'
                        : library.permissionBlocked
                            ? 'Abrir ajustes'
                            : 'Escanear',
                    onAction: library.isScanning
                        ? null
                        : library.permissionBlocked
                            ? () => library.openSystemSettings()
                            : () async {
                                final ok = await library.scan();
                                if (!context.mounted) return;
                                showAppSnack(
                                  context,
                                  ok
                                      ? '${library.totalSongs} faixas encontradas.'
                                      : (library.error ??
                                          'Nenhuma música encontrada.'),
                                );
                              },
                  )
                : searching
                    ? (_results.isEmpty
                        ? EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'Nenhum resultado',
                            message:
                                'Não encontramos “$_query” em ${_field.label.toLowerCase()}. '
                                'Tente outra palavra ou outro campo.',
                          )
                        : SongListView(
                            songs: _results,
                            queueLabel: 'Pesquisa “$_query”',
                            onTap: (song, index) {
                              _searchFocus.unfocus();
                              player.playSongs(
                                _results,
                                index: index,
                                label: 'Pesquisa “$_query”',
                              );
                            },
                          ))
                    : songs.isEmpty
                        ? EmptyState(
                            icon: Icons.filter_alt_off_rounded,
                            title: 'Nenhuma faixa com esses filtros',
                            message:
                                'Tente outra combinação de formato, qualidade ou pasta.',
                            actionLabel: 'Limpar filtros',
                            onAction: library.clearFilters,
                          )
                        : SongListView(
                            songs: songs,
                            queueLabel: 'Biblioteca',
                            onTap: (song, index) => player.playSongs(
                              songs,
                              index: index,
                              label: 'Biblioteca',
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  void _showSort(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Consumer<LibraryController>(
          builder: (context, library, _) {
            final theme = Theme.of(context);
            final scheme = theme.colorScheme;
            return SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.85,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                        child: Text(
                          'Ordenar por',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      for (final field in SortField.values)
                        ListTile(
                          leading: Icon(_sortIcon(field)),
                          title: Text(field.label),
                          selected: library.sortField == field,
                          trailing: library.sortField == field
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: scheme.primary,
                                )
                              : null,
                          onTap: () => library.setSortField(field),
                        ),
                      const Divider(),
                      SwitchListTile(
                        value: library.sortAscending,
                        onChanged: (_) => library.toggleSortDirection(),
                        secondary: Icon(
                          library.sortAscending
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                        ),
                        title: Text(
                          library.sortAscending
                              ? 'Crescente (A → Z)'
                              : 'Decrescente (Z → A)',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFilters(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Consumer<LibraryController>(
              builder: (context, library, _) {
                final theme = Theme.of(context);
                final scheme = theme.colorScheme;
                return Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 12, 6),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Filtros',
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                          TextButton(
                            onPressed: library.hasActiveFilters
                                ? library.clearFilters
                                : null,
                            child: const Text('Limpar tudo'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        children: <Widget>[
                          _FilterSectionTitle(
                            title: 'Formato',
                            subtitle: 'Selecione um ou mais formatos',
                            trailing: '${library.formats.length}',
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              for (final format in library.formats)
                                FilterChip(
                                  label: Text(format),
                                  selected:
                                      library.formatFilters.contains(format),
                                  onSelected: (_) => library.toggleFormat(format),
                                ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          const _FilterSectionTitle(
                            title: 'Qualidade',
                            subtitle: 'Estimada pelo formato e bitrate',
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              for (final quality in QualityFilter.values)
                                ChoiceChip(
                                  label: Text(quality.label),
                                  selected: library.qualityFilter == quality,
                                  onSelected: (_) =>
                                      library.setQualityFilter(quality),
                                ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          _FilterSectionTitle(
                            title: 'Pasta',
                            subtitle: 'Armazenamento interno e microSD',
                            trailing: '${library.folders.length}',
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              ChoiceChip(
                                label: const Text('Todas'),
                                selected: library.folderFilter == null,
                                onSelected: (_) =>
                                    library.setFolderFilter(null),
                              ),
                              for (final folder in library.folders)
                                ChoiceChip(
                                  label: Text(folder),
                                  selected: library.folderFilter == folder,
                                  onSelected: (_) =>
                                      library.setFolderFilter(folder),
                                ),
                            ],
                          ),
                          const SizedBox(height: 26),
                          FilledButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.check_rounded,
                              color: scheme.onPrimary,
                            ),
                            label: Text(
                              'Ver ${library.filteredSongs.length} faixa(s)',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showView(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Consumer<SettingsController>(
          builder: (context, settings, _) {
            final theme = Theme.of(context);
            final scheme = theme.colorScheme;
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Visualização', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 14),
                    SegmentedButton<ViewMode>(
                      showSelectedIcon: false,
                      segments: const <ButtonSegment<ViewMode>>[
                        ButtonSegment<ViewMode>(
                          value: ViewMode.list,
                          icon: Icon(Icons.view_agenda_outlined),
                          label: Text('Lista'),
                        ),
                        ButtonSegment<ViewMode>(
                          value: ViewMode.grid,
                          icon: Icon(Icons.grid_view_rounded),
                          label: Text('Grade'),
                        ),
                        ButtonSegment<ViewMode>(
                          value: ViewMode.compact,
                          icon: Icon(Icons.view_headline_rounded),
                          label: Text('Compacta'),
                        ),
                      ],
                      selected: <ViewMode>{settings.viewMode},
                      onSelectionChanged: (selection) =>
                          settings.setViewMode(selection.first),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Itens por linha na grade',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          '${settings.gridColumns}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: settings.gridColumns.toDouble(),
                      min: 2,
                      max: 6,
                      divisions: 4,
                      label: '${settings.gridColumns} colunas',
                      onChanged: (value) =>
                          settings.setGridColumns(value.round()),
                    ),
                    Text(
                      'Ajuste de 2 a 6 colunas. O app mantém apenas 4× as capas visíveis em memória, então a grade continua leve.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.memory_rounded,
                            color: scheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'A janela de capas acompanha o que está na tela automaticamente.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static IconData _sortIcon(SortField field) => switch (field) {
        SortField.title => Icons.title_rounded,
        SortField.artist => Icons.person_rounded,
        SortField.album => Icons.album_rounded,
        SortField.dateAdded => Icons.calendar_month_rounded,
        SortField.duration => Icons.timer_outlined,
        SortField.format => Icons.audio_file_rounded,
        SortField.quality => Icons.high_quality_rounded,
        SortField.plays => Icons.trending_up_rounded,
        SortField.folder => Icons.folder_rounded,
      };
}

/// Chips compactos de buscas recentes, exibidos só quando o campo tem foco.
class _RecentSearchRow extends StatelessWidget {
  const _RecentSearchRow({
    required this.searches,
    required this.onSelect,
    required this.onClear,
  });

  final List<String> searches;
  final void Function(String value) onSelect;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (searches.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        children: <Widget>[
          for (final search in searches)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.history_rounded, size: 16),
                label: Text(search),
                visualDensity: VisualDensity.compact,
                onPressed: () => onSelect(search),
              ),
            ),
          TextButton(
            onPressed: onClear,
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
