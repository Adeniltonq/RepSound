import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'core/localization.dart';
import 'data/backup_service.dart';
import 'data/daily_controller.dart';
import 'data/playlist_controller.dart';
import 'data/song_card_cache.dart';
import 'data/style_controller.dart';
import 'state/library_controller.dart';
import 'state/player_controller.dart';
import 'state/settings_controller.dart';
import 'ui/shell.dart';

class RepSoundApp extends StatelessWidget {
  const RepSoundApp({
    super.key,
    required this.settings,
    required this.profile,
    required this.library,
    required this.player,
    required this.cards,
    required this.backup,
    required this.styles,
    required this.daily,
  });

  final SettingsController settings;
  final PlaylistController profile;
  final LibraryController library;
  final PlayerController player;
  final SongCardCache cards;
  final BackupService backup;
  final StyleController styles;
  final DailyController daily;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<PlaylistController>.value(value: profile),
        ChangeNotifierProvider<LibraryController>.value(value: library),
        ChangeNotifierProvider<PlayerController>.value(value: player),
        ChangeNotifierProvider<SongCardCache>.value(value: cards),
        Provider<BackupService>.value(value: backup),
        ChangeNotifierProvider<StyleController>.value(value: styles),
        ChangeNotifierProvider<DailyController>.value(value: daily),
      ],
      child: Consumer<SettingsController>(
        builder: (context, current, _) {
          return MaterialApp(
            title: 'RepSound',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(
              accent: current.accentColor,
              animations: current.animations,
            ),
            darkTheme: AppTheme.dark(
              accent: current.accentColor,
              animations: current.animations,
            ),
            themeMode: current.themeMode,
            locale: current.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            themeAnimationDuration:
                current.animations ? kThemeAnimationDuration : Duration.zero,
            home: const Shell(),
          );
        },
      ),
    );
  }
}

/// Tela exibida se a inicialização falhar (armazenamento indisponível etc.).
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RepSound',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.music_off_rounded,
                      size: 36,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Não foi possível iniciar o RepSound',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Feche o app e abra novamente. Se o problema continuar, verifique o espaço livre do aparelho.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF9AA6B8), height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF6B7688),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
