import 'package:flutter/material.dart';

/// Abas da barra inferior. A ordem e a aba inicial são personalizáveis.
enum AppTab { home, library, browse, playlists, settings }

extension AppTabInfo on AppTab {
  /// Chave usada no dicionário de idiomas.
  String get labelKey => switch (this) {
        AppTab.home => 'nav.home',
        AppTab.library => 'nav.library',
        AppTab.browse => 'nav.browse',
        AppTab.playlists => 'nav.playlists',
        AppTab.settings => 'nav.settings',
      };

  /// Rótulo padrão (pt-BR), usado quando não há tradução.
  String get label => switch (this) {
        AppTab.home => 'Início',
        AppTab.library => 'Biblioteca',
        AppTab.browse => 'Navegar',
        AppTab.playlists => 'Playlists',
        AppTab.settings => 'Ajustes',
      };

  IconData get icon => switch (this) {
        AppTab.home => Icons.home_outlined,
        AppTab.library => Icons.library_music_outlined,
        AppTab.browse => Icons.explore_outlined,
        AppTab.playlists => Icons.queue_music_outlined,
        AppTab.settings => Icons.tune_outlined,
      };

  IconData get selectedIcon => switch (this) {
        AppTab.home => Icons.home_rounded,
        AppTab.library => Icons.library_music_rounded,
        AppTab.browse => Icons.explore_rounded,
        AppTab.playlists => Icons.queue_music_rounded,
        AppTab.settings => Icons.tune_rounded,
      };
}

const List<AppTab> defaultTabOrder = <AppTab>[
  AppTab.home,
  AppTab.library,
  AppTab.browse,
  AppTab.playlists,
  AppTab.settings,
];

AppTab? appTabFromName(String? name) {
  if (name == null) return null;
  for (final tab in AppTab.values) {
    if (tab.name == name) return tab;
  }
  return null;
}
