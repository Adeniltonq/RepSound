import '../data/models.dart';

/// Uma entrada da fila. [manual] marca faixas adicionadas pelo usuário
/// ("tocar a seguir" / "adicionar à fila"), que tocam antes do restante
/// do contexto.
class QueueEntry {
  const QueueEntry({required this.song, this.manual = false});

  final Song song;
  final bool manual;
}

/// Fila de reprodução definida por um contexto (biblioteca, pesquisa, álbum,
/// playlist...). Guarda o contexto original para permitir "Restaurar fila"
/// e as edições manuais do usuário.
class PlaybackQueue {
  PlaybackQueue({
    required List<Song> contextSongs,
    required this.originLabel,
    int initialIndex = 0,
  })  : contextSongs = List<Song>.unmodifiable(contextSongs),
        entries = <QueueEntry>[
          for (final song in contextSongs) QueueEntry(song: song),
        ],
        _currentIndex = contextSongs.isEmpty
            ? 0
            : initialIndex.clamp(0, contextSongs.length - 1);

  PlaybackQueue._restored({
    required this.contextSongs,
    required this.originLabel,
    required this.entries,
    required int currentIndex,
  }) : _currentIndex = entries.isEmpty
            ? 0
            : currentIndex.clamp(0, entries.length - 1);

  /// Lista original do contexto, na ordem exibida quando o usuário tocou.
  final List<Song> contextSongs;

  /// Texto do contexto exibido na fila ("Biblioteca", "Pesquisa ...").
  final String originLabel;

  final List<QueueEntry> entries;
  int _currentIndex;

  int get currentIndex => _currentIndex;
  bool get isEmpty => entries.isEmpty;
  int get length => entries.length;

  Song? get currentSong =>
      _currentIndex >= 0 && _currentIndex < entries.length
          ? entries[_currentIndex].song
          : null;

  List<Song> get songs =>
      <Song>[for (final entry in entries) entry.song];

  /// Há edições manuais ou reordenação em relação ao contexto original.
  bool get isEdited {
    if (entries.length != contextSongs.length) return true;
    if (entries.any((entry) => entry.manual)) return true;
    final contextIds = <String>[for (final song in contextSongs) song.id];
    final currentIds = <String>[
      for (final entry in entries)
        if (!entry.manual) entry.song.id,
    ];
    if (contextIds.length != currentIds.length) return true;
    for (var index = 0; index < contextIds.length; index++) {
      if (contextIds[index] != currentIds[index]) return true;
    }
    return false;
  }

  void setCurrentIndex(int index) {
    if (entries.isEmpty) {
      _currentIndex = 0;
      return;
    }
    _currentIndex = index.clamp(0, entries.length - 1);
  }

  /// Insere logo depois da faixa atual ("tocar a seguir").
  int addNext(Song song) {
    final index = _currentIndex + 1;
    entries.insert(index, QueueEntry(song: song, manual: true));
    return index;
  }

  /// Insere depois das adições manuais já pendentes, antes do restante
  /// do contexto ("adicionar à fila").
  int addToQueue(Song song) {
    var index = _currentIndex + 1;
    while (index < entries.length && entries[index].manual) {
      index++;
    }
    entries.insert(index, QueueEntry(song: song, manual: true));
    return index;
  }

  /// Remove uma faixa pendente. A faixa atual não pode ser removida.
  bool removeAt(int index) {
    if (index < 0 || index >= entries.length || index == _currentIndex) {
      return false;
    }
    final current = entries[_currentIndex];
    entries.removeAt(index);
    _currentIndex = entries.indexOf(current);
    return true;
  }

  /// Move uma faixa (reordenação manual).
  void move(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= entries.length) return;
    final current = entries[_currentIndex];
    final entry = entries.removeAt(oldIndex);
    final target = newIndex.clamp(0, entries.length);
    entries.insert(target, entry);
    _currentIndex = entries.indexOf(current);
  }

  /// Limpa as faixas pendentes; a faixa atual continua até o fim.
  void clearPending() {
    final current = currentSong;
    entries.clear();
    if (current != null) entries.add(QueueEntry(song: current));
    _currentIndex = 0;
  }

  /// Descarta edições manuais e reconstrói a fila a partir do contexto,
  /// mantendo a faixa que está tocando.
  void restoreContext() {
    final current = currentSong;
    entries
      ..clear()
      ..addAll(<QueueEntry>[
        for (final song in contextSongs) QueueEntry(song: song),
      ]);
    if (current == null) {
      _currentIndex = 0;
      return;
    }
    final index = entries.indexWhere((entry) => entry.song.id == current.id);
    if (index >= 0) {
      _currentIndex = index;
    } else {
      entries.insert(0, QueueEntry(song: current));
      _currentIndex = 0;
    }
  }

  Map<String, dynamic> toJson({int positionMs = 0}) => <String, dynamic>{
        'version': 1,
        'origin': originLabel,
        'contextIds': <String>[for (final song in contextSongs) song.id],
        'entries': <Map<String, dynamic>>[
          for (final entry in entries)
            <String, dynamic>{'id': entry.song.id, 'manual': entry.manual},
        ],
        'currentIndex': _currentIndex,
        'currentId': currentSong?.id,
        'positionMs': positionMs,
      };

  /// Reconstrói a fila a partir do JSON salvo, ignorando faixas que não
  /// existem mais na biblioteca.
  static PlaybackQueue? fromJson(
    Map<String, dynamic> raw,
    Song? Function(String id) resolve,
  ) {
    final entries = <QueueEntry>[];
    final rawEntries = raw['entries'];
    if (rawEntries is List) {
      for (final item in rawEntries) {
        if (item is! Map) continue;
        final id = item['id']?.toString();
        if (id == null) continue;
        final song = resolve(id);
        if (song == null) continue;
        entries.add(
          QueueEntry(song: song, manual: item['manual'] == true),
        );
      }
    }
    final context = <Song>[];
    final rawContext = raw['contextIds'];
    if (rawContext is List) {
      for (final item in rawContext) {
        final song = resolve(item.toString());
        if (song != null) context.add(song);
      }
    }
    if (entries.isEmpty) return null;

    final currentId = raw['currentId']?.toString();
    var currentIndex = (raw['currentIndex'] as num?)?.toInt() ?? 0;
    if (currentId != null) {
      final found = entries.indexWhere((entry) => entry.song.id == currentId);
      if (found >= 0) currentIndex = found;
    }

    return PlaybackQueue._restored(
      contextSongs: List<Song>.unmodifiable(context),
      originLabel: raw['origin']?.toString() ?? '',
      entries: entries,
      currentIndex: currentIndex,
    );
  }
}
