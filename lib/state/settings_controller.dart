import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_theme.dart';
import '../data/models.dart';
import 'app_tab.dart';

/// Preferências do app (persistidas em SharedPreferences e exportáveis).
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs) {
    _read();
  }

  static Future<SettingsController> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsController(prefs);
  }

  final SharedPreferences _prefs;

  static const _kTheme = 'rs_theme';
  static const _kAccent = 'rs_accent';
  static const _kView = 'rs_view_mode';
  static const _kGridColumns = 'rs_grid_columns';
  static const _kSort = 'rs_sort_field';
  static const _kSortAsc = 'rs_sort_asc';
  static const _kPlaybackQuality = 'rs_playback_quality';
  static const _kEqEnabled = 'rs_eq_enabled';
  static const _kEqPreset = 'rs_eq_preset';
  static const _kEqGains = 'rs_eq_gains';
  static const _kBassBoost = 'rs_bass_boost';
  static const _kAutoBackup = 'rs_auto_backup';
  static const _kLastBackup = 'rs_last_backup';
  static const _kRecentSearches = 'rs_recent_searches';
  static const _kMinDuration = 'rs_min_duration';
  static const _kAnimations = 'rs_animations';
  static const _kShuffle = 'rs_shuffle';
  static const _kRepeat = 'rs_repeat';
  static const _kLocale = 'rs_locale';
  static const _kTabOrder = 'rs_tab_order';
  static const _kInitialTab = 'rs_initial_tab';

  ThemeMode _themeMode = ThemeMode.dark;
  int _accentIndex = 0;
  ViewMode _viewMode = ViewMode.list;
  int _gridColumns = 3;
  SortField _sortField = SortField.title;
  bool _sortAscending = true;
  PlaybackQuality _playbackQuality = PlaybackQuality.auto;
  bool _eqEnabled = true;
  String _eqPreset = 'flat';
  List<double> _eqGains = const <double>[];
  double _bassBoost = 0;
  bool _autoBackup = false;
  int _lastBackupMs = 0;
  List<String> _recentSearches = <String>[];
  int _minDurationSec = 20;
  bool _animations = true;
  bool _shuffle = false;
  String _repeatMode = 'off';
  String _localeCode = 'pt';
  List<AppTab> _tabOrder = List<AppTab>.of(defaultTabOrder);
  AppTab _initialTab = AppTab.home;

  ThemeMode get themeMode => _themeMode;
  String get localeCode => _localeCode;
  Locale get locale => Locale(_localeCode);
  int get accentIndex => _accentIndex;
  Color get accentColor =>
      AppColors.accents[_accentIndex.clamp(0, AppColors.accents.length - 1).toInt()];
  ViewMode get viewMode => _viewMode;
  int get gridColumns => _gridColumns;
  SortField get sortField => _sortField;
  bool get sortAscending => _sortAscending;
  PlaybackQuality get playbackQuality => _playbackQuality;

  /// Resolução das capas pedida ao MediaStore conforme o perfil escolhido.
  int get artworkSize => switch (_playbackQuality) {
        PlaybackQuality.high => 512,
        PlaybackQuality.saver => 192,
        PlaybackQuality.auto => 320,
      };
  bool get eqEnabled => _eqEnabled;
  String get eqPreset => _eqPreset;
  List<double> get eqGains => List<double>.unmodifiable(_eqGains);
  double get bassBoost => _bassBoost;
  bool get autoBackup => _autoBackup;
  int get lastBackupMs => _lastBackupMs;
  List<String> get recentSearches => List<String>.unmodifiable(_recentSearches);
  int get minDurationSec => _minDurationSec;
  bool get animations => _animations;
  bool get shuffle => _shuffle;
  String get repeatMode => _repeatMode;
  List<AppTab> get tabOrder => List<AppTab>.unmodifiable(_tabOrder);
  AppTab get initialTab => _initialTab;
  int get initialTabIndex {
    final index = _tabOrder.indexOf(_initialTab);
    return index < 0 ? 0 : index;
  }

  void _read() {
    _themeMode = switch (_prefs.getString(_kTheme)) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    _accentIndex = _prefs.getInt(_kAccent) ?? 0;
    _viewMode = _enumByName(
      ViewMode.values,
      _prefs.getString(_kView),
      ViewMode.list,
    );
    _gridColumns = (_prefs.getInt(_kGridColumns) ?? 3).clamp(2, 6).toInt();
    _sortField = _enumByName(
      SortField.values,
      _prefs.getString(_kSort),
      SortField.title,
    );
    _sortAscending = _prefs.getBool(_kSortAsc) ?? true;
    _playbackQuality = _enumByName(
      PlaybackQuality.values,
      _prefs.getString(_kPlaybackQuality),
      PlaybackQuality.auto,
    );
    _eqEnabled = _prefs.getBool(_kEqEnabled) ?? true;
    _eqPreset = _prefs.getString(_kEqPreset) ?? 'flat';
    _eqGains = _decodeDoubles(_prefs.getString(_kEqGains));
    _bassBoost = _prefs.getDouble(_kBassBoost) ?? 0;
    _autoBackup = _prefs.getBool(_kAutoBackup) ?? false;
    _lastBackupMs = _prefs.getInt(_kLastBackup) ?? 0;
    _recentSearches = _prefs.getStringList(_kRecentSearches) ?? <String>[];
    _minDurationSec = _prefs.getInt(_kMinDuration) ?? 20;
    _animations = _prefs.getBool(_kAnimations) ?? true;
    _shuffle = _prefs.getBool(_kShuffle) ?? false;
    _repeatMode = _prefs.getString(_kRepeat) ?? 'off';
    _localeCode = _prefs.getString(_kLocale) ?? 'pt';
    _tabOrder = _decodeTabOrder(_prefs.getStringList(_kTabOrder));
    _initialTab =
        appTabFromName(_prefs.getString(_kInitialTab)) ?? AppTab.home;
    if (!_tabOrder.contains(_initialTab)) _initialTab = _tabOrder.first;
  }

  static List<AppTab> _decodeTabOrder(List<String>? raw) {
    final result = <AppTab>[];
    if (raw != null) {
      for (final name in raw) {
        final tab = appTabFromName(name);
        if (tab != null && !result.contains(tab)) result.add(tab);
      }
    }
    for (final tab in defaultTabOrder) {
      if (!result.contains(tab)) result.add(tab);
    }
    return result;
  }

  void setLocale(String code) {
    if (_localeCode == code) return;
    _localeCode = code;
    _prefs.setString(_kLocale, code);
    notifyListeners();
  }

  void setThemeMode(ThemeMode value) {
    if (_themeMode == value) return;
    _themeMode = value;
    _prefs.setString(_kTheme, value.name);
    notifyListeners();
  }

  void setAccentIndex(int value) {
    final clamped = value.clamp(0, AppColors.accents.length - 1).toInt();
    if (_accentIndex == clamped) return;
    _accentIndex = clamped;
    _prefs.setInt(_kAccent, clamped);
    notifyListeners();
  }

  void setViewMode(ViewMode value) {
    if (_viewMode == value) return;
    _viewMode = value;
    _prefs.setString(_kView, value.name);
    notifyListeners();
  }

  void setGridColumns(int value) {
    final clamped = value.clamp(2, 6).toInt();
    if (_gridColumns == clamped) return;
    _gridColumns = clamped;
    _prefs.setInt(_kGridColumns, clamped);
    notifyListeners();
  }

  void setSortField(SortField value) {
    if (_sortField == value) return;
    _sortField = value;
    _prefs.setString(_kSort, value.name);
    notifyListeners();
  }

  void setSortAscending(bool value) {
    if (_sortAscending == value) return;
    _sortAscending = value;
    _prefs.setBool(_kSortAsc, value);
    notifyListeners();
  }

  void setPlaybackQuality(PlaybackQuality value) {
    if (_playbackQuality == value) return;
    _playbackQuality = value;
    _prefs.setString(_kPlaybackQuality, value.name);
    notifyListeners();
  }

  void setEqEnabled(bool value) {
    if (_eqEnabled == value) return;
    _eqEnabled = value;
    _prefs.setBool(_kEqEnabled, value);
    notifyListeners();
  }

  void setEqPreset(String value) {
    if (_eqPreset == value) return;
    _eqPreset = value;
    _prefs.setString(_kEqPreset, value);
    notifyListeners();
  }

  void setEqGains(List<double> gains) {
    _eqGains = List<double>.of(gains);
    _prefs.setString(_kEqGains, _encodeDoubles(_eqGains));
    notifyListeners();
  }

  void setBassBoost(double value) {
    final clamped = value.clamp(0, 12).toDouble();
    if ((_bassBoost - clamped).abs() < 0.05) return;
    _bassBoost = clamped;
    _prefs.setDouble(_kBassBoost, clamped);
    notifyListeners();
  }

  void setAutoBackup(bool value) {
    if (_autoBackup == value) return;
    _autoBackup = value;
    _prefs.setBool(_kAutoBackup, value);
    notifyListeners();
  }

  void markBackupDone() {
    _lastBackupMs = DateTime.now().millisecondsSinceEpoch;
    _prefs.setInt(_kLastBackup, _lastBackupMs);
    notifyListeners();
  }

  void addRecentSearch(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return;
    _recentSearches.removeWhere(
      (item) => item.toLowerCase() == clean.toLowerCase(),
    );
    _recentSearches.insert(0, clean);
    if (_recentSearches.length > 8) {
      _recentSearches = _recentSearches.take(8).toList();
    }
    _prefs.setStringList(_kRecentSearches, _recentSearches);
    notifyListeners();
  }

  void clearRecentSearches() {
    _recentSearches = <String>[];
    _prefs.remove(_kRecentSearches);
    notifyListeners();
  }

  void setMinDurationSec(int value) {
    final clamped = value.clamp(0, 120).toInt();
    if (_minDurationSec == clamped) return;
    _minDurationSec = clamped;
    _prefs.setInt(_kMinDuration, clamped);
    notifyListeners();
  }

  void setAnimations(bool value) {
    if (_animations == value) return;
    _animations = value;
    _prefs.setBool(_kAnimations, value);
    notifyListeners();
  }

  void setShuffle(bool value) {
    if (_shuffle == value) return;
    _shuffle = value;
    _prefs.setBool(_kShuffle, value);
    notifyListeners();
  }

  void setRepeatMode(String value) {
    if (_repeatMode == value) return;
    _repeatMode = value;
    _prefs.setString(_kRepeat, value);
    notifyListeners();
  }

  void setTabOrder(List<AppTab> order) {
    final normalized = _decodeTabOrder(
      order.map((tab) => tab.name).toList(),
    );
    if (listEquals(_tabOrder, normalized)) return;
    _tabOrder = normalized;
    if (!_tabOrder.contains(_initialTab)) _initialTab = _tabOrder.first;
    _prefs.setStringList(
      _kTabOrder,
      _tabOrder.map((tab) => tab.name).toList(),
    );
    _prefs.setString(_kInitialTab, _initialTab.name);
    notifyListeners();
  }

  void setInitialTab(AppTab tab) {
    if (_initialTab == tab) return;
    _initialTab = tab;
    _prefs.setString(_kInitialTab, tab.name);
    notifyListeners();
  }

  void resetTabBar() {
    _tabOrder = List<AppTab>.of(defaultTabOrder);
    _initialTab = AppTab.home;
    _prefs.remove(_kTabOrder);
    _prefs.remove(_kInitialTab);
    notifyListeners();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'theme': _themeMode.name,
        'accentIndex': _accentIndex,
        'viewMode': _viewMode.name,
        'gridColumns': _gridColumns,
        'sortField': _sortField.name,
        'sortAscending': _sortAscending,
        'playbackQuality': _playbackQuality.name,
        'eqEnabled': _eqEnabled,
        'eqPreset': _eqPreset,
        'eqGains': _eqGains,
        'bassBoost': _bassBoost,
        'autoBackup': _autoBackup,
        'minDurationSec': _minDurationSec,
        'animations': _animations,
        'shuffle': _shuffle,
        'repeatMode': _repeatMode,
        'tabOrder': _tabOrder.map((tab) => tab.name).toList(),
        'initialTab': _initialTab.name,
      };

  Future<void> applyJson(Map<String, dynamic> json) async {
    final theme = json['theme'];
    if (theme is String) {
      _themeMode = switch (theme) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };
      await _prefs.setString(_kTheme, _themeMode.name);
    }
    final accent = json['accentIndex'];
    if (accent is num) {
      _accentIndex = accent.toInt().clamp(0, AppColors.accents.length - 1).toInt();
      await _prefs.setInt(_kAccent, _accentIndex);
    }
    final view = json['viewMode'];
    if (view is String) {
      _viewMode = _enumByName(ViewMode.values, view, _viewMode);
      await _prefs.setString(_kView, _viewMode.name);
    }
    final columns = json['gridColumns'];
    if (columns is num) {
      _gridColumns = columns.toInt().clamp(2, 6).toInt();
      await _prefs.setInt(_kGridColumns, _gridColumns);
    }
    final sort = json['sortField'];
    if (sort is String) {
      _sortField = _enumByName(SortField.values, sort, _sortField);
      await _prefs.setString(_kSort, _sortField.name);
    }
    final ascending = json['sortAscending'];
    if (ascending is bool) {
      _sortAscending = ascending;
      await _prefs.setBool(_kSortAsc, ascending);
    }
    final quality = json['playbackQuality'];
    if (quality is String) {
      _playbackQuality = _enumByName(
        PlaybackQuality.values,
        quality,
        _playbackQuality,
      );
      await _prefs.setString(_kPlaybackQuality, _playbackQuality.name);
    }
    final eq = json['eqEnabled'];
    if (eq is bool) {
      _eqEnabled = eq;
      await _prefs.setBool(_kEqEnabled, eq);
    }
    final preset = json['eqPreset'];
    if (preset is String) {
      _eqPreset = preset;
      await _prefs.setString(_kEqPreset, preset);
    }
    final gains = json['eqGains'];
    if (gains is List) {
      _eqGains = gains
          .whereType<num>()
          .map((value) => value.toDouble())
          .toList(growable: false);
      await _prefs.setString(_kEqGains, _encodeDoubles(_eqGains));
    }
    final bass = json['bassBoost'];
    if (bass is num) {
      _bassBoost = bass.toDouble().clamp(0, 12).toDouble();
      await _prefs.setDouble(_kBassBoost, _bassBoost);
    }
    final backup = json['autoBackup'];
    if (backup is bool) {
      _autoBackup = backup;
      await _prefs.setBool(_kAutoBackup, backup);
    }
    final minDuration = json['minDurationSec'];
    if (minDuration is num) {
      _minDurationSec = minDuration.toInt().clamp(0, 120).toInt();
      await _prefs.setInt(_kMinDuration, _minDurationSec);
    }
    final animations = json['animations'];
    if (animations is bool) {
      _animations = animations;
      await _prefs.setBool(_kAnimations, animations);
    }
    final shuffle = json['shuffle'];
    if (shuffle is bool) {
      _shuffle = shuffle;
      await _prefs.setBool(_kShuffle, shuffle);
    }
    final repeat = json['repeatMode'];
    if (repeat is String) {
      _repeatMode = repeat;
      await _prefs.setString(_kRepeat, repeat);
    }
    final tabOrder = json['tabOrder'];
    if (tabOrder is List) {
      _tabOrder = _decodeTabOrder(
        tabOrder.map((entry) => entry.toString()).toList(),
      );
      await _prefs.setStringList(
        _kTabOrder,
        _tabOrder.map((tab) => tab.name).toList(),
      );
    }
    final initialTab = json['initialTab'];
    if (initialTab is String) {
      final tab = appTabFromName(initialTab);
      if (tab != null && _tabOrder.contains(tab)) {
        _initialTab = tab;
        await _prefs.setString(_kInitialTab, tab.name);
      }
    }
    notifyListeners();
  }

  static T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
    if (name == null) return fallback;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  static List<double> _decodeDoubles(String? raw) {
    if (raw == null || raw.isEmpty) return const <double>[];
    return raw
        .split(',')
        .map((value) => double.tryParse(value))
        .whereType<double>()
        .toList(growable: false);
  }

  static String _encodeDoubles(List<double> values) =>
      values.map((value) => value.toStringAsFixed(1)).join(',');
}
