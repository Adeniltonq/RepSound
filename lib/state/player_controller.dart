import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../data/models.dart';
import '../data/playlist_controller.dart';
import '../data/queue_store.dart';
import '../data/song_card_cache.dart';
import '../state/library_controller.dart';
import '../state/settings_controller.dart';
import '../player/equalizer_presets.dart';
import 'playback_queue.dart';

/// Reprodução, fila, equalizador, timer e estatísticas de escuta.
///
/// A fila é gerada pelo contexto (lista de onde o usuário tocou) e pode ser
/// editada, limpa ou restaurada. Ela é persistida para sobreviver ao
/// fechamento do app.
class PlayerController extends ChangeNotifier {
  PlayerController({
    required this.cards,
    required this.profile,
    required this.settings,
    required this.library,
    required this.queueStore,
  }) {
    _player = AudioPlayer(
      audioPipeline: AudioPipeline(
        androidAudioEffects: <AndroidAudioEffect>[_equalizer, _loudness],
      ),
      handleInterruptions: true,
      androidApplyAudioAttributes: true,
      maxSkipsOnError: 3,
    );
    _initialized = true;
    _shuffle = settings.shuffle;
    _loopMode = _loopFromString(settings.repeatMode);
    _eqEnabled = settings.eqEnabled;
    _eqPreset = settings.eqPreset;
    _bassBoost = settings.bassBoost;
    _lastEqGains = settings.eqGains;
    _lastQuality = settings.playbackQuality;
    _wireStreams();
    settings.addListener(_onSettingsChanged);
    unawaited(_configureSession());
  }

  /// A fila lógica não é mais cortada: o contexto inteiro é preservado.
  /// O limite existe apenas como proteção para bibliotecas gigantes.
  int get maxQueueLength => 20000;

  /// O modo econômico desliga os efeitos de áudio.
  bool get effectsAllowed => settings.playbackQuality != PlaybackQuality.saver;

  int get _prefetchRadius => switch (settings.playbackQuality) {
        PlaybackQuality.high => 5,
        PlaybackQuality.auto => 3,
        PlaybackQuality.saver => 1,
      };

  final SongCardCache cards;
  final PlaylistController profile;
  final SettingsController settings;
  final LibraryController library;
  final QueueStore queueStore;

  late final AudioPlayer _player;
  final AndroidEqualizer _equalizer = AndroidEqualizer();
  final AndroidLoudnessEnhancer _loudness = AndroidLoudnessEnhancer();
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  PlaybackQueue? _queue;
  bool _initialized = false;
  bool _listenCounted = false;
  String? _trackedSongId;
  double _currentMaxRatio = 0;
  bool _trackCompleted = false;
  bool _finalizedCurrent = false;
  bool _shuffle = false;
  LoopMode _loopMode = LoopMode.off;
  String? _error;
  String? _notice;
  bool _queueLimited = false;
  Timer? _queueSaveTimer;

  List<AndroidEqualizerBand> _bands = const <AndroidEqualizerBand>[];
  double _eqMin = -12;
  double _eqMax = 12;
  bool _eqReady = false;
  bool _eqLoading = false;
  bool _eqEnabled = true;
  String _eqPreset = 'flat';
  double _bassBoost = 0;
  List<double> _lastEqGains = const <double>[];
  PlaybackQuality _lastQuality = PlaybackQuality.auto;

  Timer? _sleepTicker;
  Duration? _sleepRemaining;
  bool _sleepAtTrackEnd = false;

  bool get isInitialized => _initialized;
  bool get isPlaying => _player.playing;
  bool get isShuffling => _shuffle;
  bool get hasHardwareEqualizer => !kIsWeb && Platform.isAndroid;
  LoopMode get loopMode => _loopMode;
  String get contextLabel => _queue?.originLabel ?? '';
  String? get error => _error;
  String? get notice => _notice;
  bool get queueLimited => _queueLimited;
  List<Song> get queue =>
      _queue == null ? const <Song>[] : List<Song>.unmodifiable(_queue!.songs);
  int? get currentIndex => _queue?.currentIndex;
  bool get hasQueue => _queue != null && _queue!.length > 0;
  bool get canRestoreQueue => _queue?.isEdited ?? false;
  Duration? get sleepRemaining => _sleepRemaining;
  bool get sleepAtTrackEnd => _sleepAtTrackEnd;

  AudioPlayer get player => _player;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Song? get currentSong => _queue?.currentSong;

  String get repeatLabel => switch (_loopMode) {
        LoopMode.off => 'Repetir desligado',
        LoopMode.all => 'Repetir fila',
        LoopMode.one => 'Repetir faixa',
      };

  // ------------------------------------------------------------------ setup

  Future<void> _configureSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (error) {
      debugPrint('AudioSession: $error');
    }
  }

  void _wireStreams() {
    _subscriptions.add(
      _player.currentIndexStream.listen(_onIndexChanged),
    );
    _subscriptions.add(
      _player.playerStateStream.listen((_) => notifyListeners()),
    );
    _subscriptions.add(
      _player.positionStream.listen(_onPositionChanged),
    );
    _subscriptions.add(
      _player.processingStateStream.listen(_onProcessingState),
    );
    _subscriptions.add(
      _player.errorStream.listen((error) {
        _error = 'Não foi possível reproduzir esta faixa.';
        debugPrint('Player error: $error');
        notifyListeners();
      }),
    );
    unawaited(_player.setLoopMode(_loopMode));
    unawaited(_player.setShuffleModeEnabled(_shuffle));
  }

  void _onIndexChanged(int? index) {
    final queue = _queue;
    if (index == null || queue == null) return;
    if (index < 0 || index >= queue.length) {
      notifyListeners();
      return;
    }
    final previous = queue.currentSong;
    queue.setCurrentIndex(index);
    final song = queue.currentSong;
    if (song == null) {
      notifyListeners();
      return;
    }
    // Inserções/remoções deslocam o índice sem trocar a faixa atual.
    if (previous?.id == song.id) {
      notifyListeners();
      return;
    }
    if (previous != null && !_finalizedCurrent) {
      _finalizeTrack(previous, completed: _trackCompleted);
    }
    _listenCounted = false;
    _trackedSongId = song.id;
    _currentMaxRatio = 0;
    _trackCompleted = false;
    _finalizedCurrent = false;
    profile.recordPlayStart(song);
    cards.prefetchAround(queue.songs, index, radius: _prefetchRadius);
    unawaited(_applyEqualizerWhenReady());
    _persistQueueSoon();
    notifyListeners();
  }

  void _onPositionChanged(Duration position) {
    final song = currentSong;
    if (song == null) return;
    if (_trackedSongId != song.id) {
      _trackedSongId = song.id;
      _currentMaxRatio = 0;
      _trackCompleted = false;
      _finalizedCurrent = false;
      _listenCounted = false;
    }
    final durationMs = _player.duration?.inMilliseconds ?? song.durationMs;
    if (durationMs > 0) {
      final ratio = (position.inMilliseconds / durationMs).clamp(0.0, 1.0);
      if (ratio > _currentMaxRatio) _currentMaxRatio = ratio;
      // Repetir a mesma faixa recomeça a contagem.
      if (_finalizedCurrent && ratio < 0.4) {
        _finalizedCurrent = false;
        _listenCounted = false;
        _trackCompleted = false;
        _currentMaxRatio = ratio;
      }
    }
    if (_listenCounted) return;
    final threshold = song.durationMs > 0
        ? math.min(30000, math.max(5000, song.durationMs ~/ 2))
        : 20000;
    if (position.inMilliseconds >= threshold) {
      _listenCounted = true;
      profile.recordListen(song);
    }
  }

  /// Registra pulo, tempo ouvido e reprodução válida ao trocar de faixa.
  void _finalizeTrack(Song song, {required bool completed}) {
    final ratio = completed
        ? 1.0
        : _currentMaxRatio.clamp(0.0, 1.0).toDouble();
    if (completed && !_listenCounted) {
      _listenCounted = true;
      profile.recordListen(song);
    }
    profile.recordListened(song, ratio);
    if (!completed && !_listenCounted && ratio < 0.9) {
      profile.recordSkip(song);
    }
  }

  void _onProcessingState(ProcessingState state) {
    if (state == ProcessingState.completed) {
      final song = currentSong;
      if (song != null && !_finalizedCurrent) {
        _trackCompleted = true;
        _currentMaxRatio = 1.0;
        _finalizeTrack(song, completed: true);
        _finalizedCurrent = true;
      }
      if (_sleepAtTrackEnd) {
        _sleepAtTrackEnd = false;
        _sleepRemaining = null;
        unawaited(_player.pause());
      }
    }
    notifyListeners();
  }

  // ------------------------------------------------------------- reproduction

  Future<void> playSongs(
    List<Song> songs, {
    int index = 0,
    String label = '',
  }) async {
    if (!_initialized || songs.isEmpty) return;
    var start = index.clamp(0, songs.length - 1).toInt();
    var context = songs;
    _queueLimited = false;
    // Proteção apenas para bibliotecas gigantes; o contexto normal é inteiro.
    if (songs.length > maxQueueLength) {
      var from = start - maxQueueLength ~/ 2;
      if (from < 0) from = 0;
      if (from + maxQueueLength > songs.length) {
        from = songs.length - maxQueueLength;
      }
      context = songs.sublist(from, from + maxQueueLength);
      start = start - from;
      _queueLimited = true;
    }

    _queue = PlaybackQueue(
      contextSongs: context,
      originLabel: label,
      initialIndex: start,
    );
    _listenCounted = false;
    _trackedSongId = null;
    _currentMaxRatio = 0;
    _trackCompleted = false;
    _finalizedCurrent = false;
    _error = null;
    _notice = _queueLimited
        ? 'Fila limitada a $maxQueueLength faixas para manter a reprodução fluida.'
        : null;
    notifyListeners();

    await _loadQueueIntoPlayer(
      initialIndex: start,
      initialPosition: Duration.zero,
      autoPlay: true,
    );
  }

  Future<void> playSong(
    Song song, {
    List<Song>? queue,
    String label = '',
  }) {
    if (queue == null || queue.isEmpty) {
      return playSongs(<Song>[song], label: label);
    }
    final index = queue.indexWhere((item) => item.id == song.id);
    return playSongs(
      queue,
      index: index < 0 ? 0 : index,
      label: label,
    );
  }

  AudioSource _sourceFor(Song song) => AudioSource.uri(
        Uri.parse(song.contentUri),
        tag: MediaItem(
          id: song.id,
          title: song.title,
          artist: song.artist,
          album: song.album,
          duration: Duration(milliseconds: song.durationMs),
          artUri: cards.artworkUriFor(song),
          extras: <String, dynamic>{
            'folder': song.folder,
            'path': song.path ?? '',
          },
        ),
      );

  Future<void> _loadQueueIntoPlayer({
    required int initialIndex,
    required Duration initialPosition,
    required bool autoPlay,
    bool recordStart = true,
  }) async {
    final queue = _queue;
    if (queue == null) return;
    try {
      final current = queue.currentSong;
      if (current != null) await cards.load(current);
      final sources = <AudioSource>[
        for (final entry in queue.entries) _sourceFor(entry.song),
      ];
      await _player.setAudioSources(
        sources,
        initialIndex: initialIndex,
        initialPosition: initialPosition,
        preload: autoPlay || _player.playing,
      );
      queue.setCurrentIndex(initialIndex);
      await _player.setLoopMode(_loopMode);
      await _player.setShuffleModeEnabled(_shuffle);
      if (_shuffle) await _player.shuffle();
      if (autoPlay) {
        await _player.play();
        if (recordStart && current != null) {
          profile.recordPlayStart(current);
        }
      }
      if (current != null) {
        cards.prefetchAround(
          queue.songs,
          queue.currentIndex,
          radius: _prefetchRadius,
        );
      }
      unawaited(_applyEqualizerWhenReady());
      _persistQueueSoon();
      notifyListeners();
    } catch (error) {
      _error = 'Não foi possível reproduzir esta faixa.';
      debugPrint('playSongs: $error');
      notifyListeners();
    }
  }

  // ------------------------------------------------------------- queue edits

  /// Adiciona ao final das faixas manuais, antes do restante do contexto.
  Future<void> addToQueue(Song song) async {
    final queue = _queue;
    if (queue == null || queue.isEmpty) {
      await playSongs(<Song>[song], label: 'Fila');
      return;
    }
    final index = queue.addToQueue(song);
    try {
      await _player.insertAudioSource(index, _sourceFor(song));
    } catch (error) {
      debugPrint('addToQueue: $error');
    }
    _persistQueueSoon();
    notifyListeners();
  }

  /// Toca a faixa imediatamente depois da atual.
  Future<void> playNext(Song song) async {
    final queue = _queue;
    if (queue == null || queue.isEmpty) {
      await playSongs(<Song>[song], label: 'Fila');
      return;
    }
    final index = queue.addNext(song);
    try {
      await _player.insertAudioSource(index, _sourceFor(song));
    } catch (error) {
      debugPrint('playNext: $error');
    }
    _persistQueueSoon();
    notifyListeners();
  }

  /// Remove uma faixa pendente. Retorna `false` para a faixa atual.
  Future<bool> removeQueueAt(int index) async {
    final queue = _queue;
    if (queue == null || !queue.removeAt(index)) return false;
    try {
      await _player.removeAudioSourceAt(index);
    } catch (error) {
      debugPrint('removeQueueAt: $error');
      return false;
    }
    _persistQueueSoon();
    notifyListeners();
    return true;
  }

  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    final queue = _queue;
    if (queue == null) return;
    try {
      await _player.moveAudioSource(oldIndex, newIndex);
    } catch (error) {
      debugPrint('moveQueueItem: $error');
      return;
    }
    queue.move(oldIndex, newIndex);
    _persistQueueSoon();
    notifyListeners();
  }

  /// Remove todas as pendentes: a faixa atual continua e depois para.
  Future<void> clearQueue() async {
    final queue = _queue;
    if (queue == null || queue.isEmpty) return;
    final position = _player.position;
    final wasPlaying = _player.playing;
    final current = queue.currentSong;
    queue.clearPending();
    _loopMode = LoopMode.off;
    settings.setRepeatMode('off');
    if (current != null) {
      try {
        await _player.setAudioSources(
          <AudioSource>[_sourceFor(current)],
          initialIndex: 0,
          initialPosition: position,
        );
        await _player.setLoopMode(LoopMode.off);
        if (wasPlaying) await _player.play();
      } catch (error) {
        debugPrint('clearQueue: $error');
      }
    }
    _persistQueueSoon();
    notifyListeners();
  }

  /// Descarta edições manuais e reconstrói a fila a partir do contexto.
  Future<void> restoreQueue() async {
    final queue = _queue;
    if (queue == null || !queue.isEdited) return;
    final position = _player.position;
    final wasPlaying = _player.playing;
    queue.restoreContext();
    await _loadQueueIntoPlayer(
      initialIndex: queue.currentIndex,
      initialPosition: position,
      autoPlay: wasPlaying,
      recordStart: false,
    );
  }

  /// Restaura a fila salva ao abrir o app (sem iniciar a reprodução).
  Future<void> restoreQueueFromDisk() async {
    final raw = await queueStore.load();
    if (raw == null) return;
    final restored = PlaybackQueue.fromJson(
      raw,
      (id) => library.songById[id],
    );
    if (restored == null) {
      await queueStore.clear();
      return;
    }
    _queue = restored;
    _queueLimited = false;
    try {
      await _player.setAudioSources(
        <AudioSource>[
          for (final entry in restored.entries) _sourceFor(entry.song),
        ],
        initialIndex: restored.currentIndex,
        initialPosition: Duration(
          milliseconds: (raw['positionMs'] as num?)?.toInt() ?? 0,
        ),
        preload: false,
      );
      await _player.setLoopMode(_loopMode);
      await _player.setShuffleModeEnabled(_shuffle);
      if (_shuffle) await _player.shuffle();
    } catch (error) {
      debugPrint('restoreQueue: $error');
    }
    notifyListeners();
  }

  void _persistQueueSoon() {
    _queueSaveTimer?.cancel();
    _queueSaveTimer = Timer(const Duration(milliseconds: 700), () {
      final queue = _queue;
      if (queue == null) {
        unawaited(queueStore.clear());
        return;
      }
      unawaited(
        queueStore.save(
          queue.toJson(positionMs: _player.position.inMilliseconds),
        ),
      );
    });
  }

  Future<void> togglePlayPause() async {
    if (!_initialized) return;
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero, index: currentIndex);
    }
    if (_queue != null && _queue!.length > 0) {
      await _player.play();
    }
  }

  Future<void> next() async {
    if (_queue == null || _queue!.isEmpty) return;
    await _player.seekToNext();
  }

  Future<void> previous() async {
    if (_queue == null || _queue!.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    await _player.seekToPrevious();
  }

  Future<void> seekToIndex(int index) async {
    final queue = _queue;
    if (queue == null || index < 0 || index >= queue.length) return;
    await _player.seek(Duration.zero, index: index);
    queue.setCurrentIndex(index);
    await _player.play();
    _persistQueueSoon();
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setVolume(double value) =>
      _player.setVolume(value.clamp(0, 1).toDouble());

  Future<void> toggleShuffle() async {
    final next = !_shuffle;
    _shuffle = next;
    settings.setShuffle(next);
    await _player.setShuffleModeEnabled(next);
    if (next) {
      await _player.shuffle();
    }
    notifyListeners();
  }

  Future<void> cycleRepeatMode() async {
    final nextMode = switch (_loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    _loopMode = nextMode;
    settings.setRepeatMode(nextMode.name);
    await _player.setLoopMode(nextMode);
    notifyListeners();
  }

  Future<void> toggleFavoriteCurrent() async {
    final song = currentSong;
    if (song != null) profile.toggleFavorite(song);
  }

  // ------------------------------------------------------------------- timer

  void setSleepTimer(Duration? duration) {
    _sleepTicker?.cancel();
    _sleepTicker = null;
    _sleepRemaining = duration;
    _sleepAtTrackEnd = false;
    if (duration == null) {
      notifyListeners();
      return;
    }
    _sleepTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _sleepRemaining;
      if (remaining == null) {
        timer.cancel();
        return;
      }
      final next = remaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        timer.cancel();
        _sleepTicker = null;
        _sleepRemaining = null;
        unawaited(_player.pause());
      } else {
        _sleepRemaining = next;
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void setSleepAtTrackEnd(bool enabled) {
    _sleepTicker?.cancel();
    _sleepTicker = null;
    _sleepRemaining = null;
    _sleepAtTrackEnd = enabled;
    notifyListeners();
  }

  // -------------------------------------------------------------- equalizer

  bool get eqEnabled => _eqEnabled;
  String get eqPreset => _eqPreset;
  double get bassBoost => _bassBoost;
  double get eqMinDb => _eqMin;
  double get eqMaxDb => _eqMax;

  List<EqBandInfo> get eqBands {
    if (_bands.isNotEmpty) {
      return <EqBandInfo>[
        for (var index = 0; index < _bands.length; index++)
          EqBandInfo(
            centerFrequency: _bands[index].centerFrequency,
            gain: _gainForBand(index, _bands[index].centerFrequency),
          ),
      ];
    }
    return <EqBandInfo>[
      for (var index = 0; index < EqualizerPresets.frequencies.length; index++)
        EqBandInfo(
          centerFrequency: EqualizerPresets.frequencies[index],
          gain: _gainForBand(index, EqualizerPresets.frequencies[index]),
        ),
    ];
  }

  double _gainForBand(int index, double frequency) {
    if (_eqPreset == 'custom') {
      final gains = settings.eqGains;
      if (index < gains.length) return gains[index];
      return 0;
    }
    final preset = EqualizerPresets.byId(_eqPreset) ?? EqualizerPresets.flat;
    return preset.gainFor(frequency);
  }

  Future<void> _applyEqualizerWhenReady() async {
    if (!hasHardwareEqualizer || _eqReady || _eqLoading) return;
    _eqLoading = true;
    try {
      final parameters = await _equalizer.parameters.timeout(
        const Duration(seconds: 4),
      );
      _bands = parameters.bands;
      _eqMin = parameters.minDecibels;
      _eqMax = parameters.maxDecibels;
      _eqReady = true;
      await _applyGains();
      notifyListeners();
    } catch (error) {
      debugPrint('Equalizador indisponível: $error');
    } finally {
      _eqLoading = false;
    }
  }

  Future<void> _applyGains() async {
    if (!hasHardwareEqualizer) return;
    if (!_eqReady) {
      unawaited(_applyEqualizerWhenReady());
      return;
    }
    final active = _eqEnabled && effectsAllowed;
    try {
      await _equalizer.setEnabled(active);
      for (var index = 0; index < _bands.length; index++) {
        final band = _bands[index];
        final gain = active
            ? _gainForBand(index, band.centerFrequency)
            : 0.0;
        await band.setGain(gain.clamp(_eqMin, _eqMax).toDouble());
      }
      await _loudness.setTargetGain(active ? _bassBoost : 0);
    } catch (error) {
      debugPrint('Falha ao aplicar equalizador: $error');
    }
  }

  Future<void> setEqEnabled(bool value) async {
    _eqEnabled = value;
    settings.setEqEnabled(value);
    await _applyGains();
    notifyListeners();
  }

  Future<void> applyPreset(String presetId) async {
    _eqPreset = presetId;
    settings.setEqPreset(presetId);
    await _applyGains();
    notifyListeners();
  }

  Future<void> setBandGain(int index, double gain) async {
    final bands = eqBands;
    final gains = <double>[
      for (var i = 0; i < bands.length; i++)
        i == index ? gain : bands[i].gain,
    ];
    await setCustomGains(gains);
  }

  /// Aplica uma curva personalizada completa (usada pelos sliders).
  Future<void> setCustomGains(List<double> gains) async {
    _eqPreset = 'custom';
    settings.setEqPreset('custom');
    settings.setEqGains(gains);
    _lastEqGains = List<double>.of(gains);
    await _applyGains();
    notifyListeners();
  }

  Future<void> setBassBoost(double value) async {
    _bassBoost = value.clamp(0, 12).toDouble();
    settings.setBassBoost(_bassBoost);
    if (hasHardwareEqualizer) {
      try {
        await _loudness.setTargetGain(effectsAllowed ? _bassBoost : 0);
      } catch (_) {
        // aparelho sem suporte
      }
    }
    notifyListeners();
  }

  Future<void> resetEqualizer() async {
    _eqPreset = 'flat';
    settings.setEqPreset('flat');
    settings.setEqGains(const <double>[]);
    _bassBoost = 0;
    settings.setBassBoost(0);
    _lastEqGains = const <double>[];
    await _applyGains();
    notifyListeners();
  }

  void _onSettingsChanged() {
    if (!_initialized) return;
    if (_shuffle != settings.shuffle) {
      _shuffle = settings.shuffle;
      unawaited(_player.setShuffleModeEnabled(_shuffle));
      if (_shuffle) unawaited(_player.shuffle());
    }
    final loop = _loopFromString(settings.repeatMode);
    if (loop != _loopMode) {
      _loopMode = loop;
      unawaited(_player.setLoopMode(loop));
    }
    final eqChanged = _eqEnabled != settings.eqEnabled ||
        _eqPreset != settings.eqPreset ||
        (_bassBoost - settings.bassBoost).abs() > 0.01 ||
        !listEquals(_lastEqGains, settings.eqGains);
    final qualityChanged = _lastQuality != settings.playbackQuality;
    _eqEnabled = settings.eqEnabled;
    _eqPreset = settings.eqPreset;
    _bassBoost = settings.bassBoost;
    _lastEqGains = settings.eqGains;
    _lastQuality = settings.playbackQuality;
    if (eqChanged || qualityChanged) unawaited(_applyGains());
  }

  // ---------------------------------------------------------------- lifecycle

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void clearNotice() {
    if (_notice == null) return;
    _notice = null;
    notifyListeners();
  }

  static LoopMode _loopFromString(String value) => switch (value) {
        'all' => LoopMode.all,
        'one' => LoopMode.one,
        _ => LoopMode.off,
      };

  @override
  void dispose() {
    settings.removeListener(_onSettingsChanged);
    _sleepTicker?.cancel();
    _queueSaveTimer?.cancel();
    final queue = _queue;
    if (queue != null) {
      unawaited(
        queueStore.save(
          queue.toJson(positionMs: _player.position.inMilliseconds),
        ),
      );
    }
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }
}
