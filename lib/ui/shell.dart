import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/localization.dart';
import '../data/media_channel.dart';
import '../state/app_tab.dart';
import '../state/player_controller.dart';
import '../state/settings_controller.dart';
import 'navigation.dart';
import 'screens/browse_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/playlists_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/app_snack.dart';
import 'widgets/mini_player.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  AppTab _currentTab = AppTab.home;
  bool _tabInitialized = false;
  PlayerController? _player;
  String? _lastMessage;
  final GlobalKey<LibraryScreenState> _libraryKey =
      GlobalKey<LibraryScreenState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOpenPlayer());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_tabInitialized) {
      _tabInitialized = true;
      _currentTab = context.read<SettingsController>().initialTab;
    }
    final player = context.read<PlayerController>();
    if (!identical(_player, player)) {
      _player?.removeListener(_onPlayer);
      _player = player;
      _player!.addListener(_onPlayer);
    }
  }

  void _onPlayer() {
    final message = _player?.error ?? _player?.notice;
    if (message == null || message == _lastMessage) return;
    _lastMessage = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showAppSnack(context, message);
      _player?.clearError();
      _player?.clearNotice();
    });
  }

  void _goToTab(AppTab tab) {
    if (_currentTab == tab) return;
    setState(() => _currentTab = tab);
  }

  /// Atalho de busca da Home: abre a Biblioteca já com o campo em foco.
  void _openSearch() {
    _goToTab(AppTab.library);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _libraryKey.currentState?.focusSearch();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _maybeOpenPlayer();
  }

  Future<void> _maybeOpenPlayer() async {
    final requested = await MediaChannel.consumeOpenPlayer();
    if (!requested || !mounted) return;
    final player = context.read<PlayerController>();
    if (player.currentSong == null) return;
    await openNowPlaying(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player?.removeListener(_onPlayer);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsController>();
    final animations = settings.animations;
    final order = settings.tabOrder;
    if (!order.contains(_currentTab)) {
      _currentTab = order.first;
    }
    final screens = <AppTab, Widget>{
      AppTab.home: HomeScreen(onNavigate: _goToTab, onSearch: _openSearch),
      AppTab.library: LibraryScreen(key: _libraryKey),
      AppTab.browse: const BrowseScreen(),
      AppTab.playlists: const PlaylistsScreen(),
      AppTab.settings: const SettingsScreen(),
    };
    final index = order.indexOf(_currentTab);

    return PopScope(
      canPop: _currentTab == AppTab.home,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentTab != AppTab.home) {
          _goToTab(AppTab.home);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: index < 0 ? 0 : index,
          children: <Widget>[
            for (final tab in order) screens[tab] ?? const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: scheme.outlineVariant),
            ),
          ),
          child: Consumer<PlayerController>(
            builder: (context, player, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AnimatedSize(
                    duration: animations
                        ? const Duration(milliseconds: 220)
                        : Duration.zero,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.bottomCenter,
                    child: player.currentSong == null
                        ? const SizedBox(width: double.infinity)
                        : const MiniPlayer(),
                  ),
                  NavigationBar(
                    selectedIndex: index < 0 ? 0 : index,
                    onDestinationSelected: (value) {
                      if (value >= 0 && value < order.length) {
                        _goToTab(order[value]);
                      }
                    },
                    destinations: <NavigationDestination>[
                      for (final tab in order)
                        NavigationDestination(
                          icon: Icon(tab.icon),
                          selectedIcon: Icon(tab.selectedIcon),
                          label: context.tr(tab.labelKey),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
