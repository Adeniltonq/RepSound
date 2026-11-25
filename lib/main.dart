import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app.dart';
import 'core/app_theme.dart';
import 'data/backup_service.dart';
import 'data/daily_controller.dart';
import 'data/daily_store.dart';
import 'data/index_store.dart';
import 'data/media_channel.dart';
import 'data/playlist_controller.dart';
import 'data/profile_store.dart';
import 'data/queue_store.dart';
import 'data/song_card_cache.dart';
import 'data/style_controller.dart';
import 'data/style_store.dart';
import 'state/library_controller.dart';
import 'state/player_controller.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.repsound.playback',
      androidNotificationChannelName: 'Reprodução',
      androidNotificationChannelDescription:
          'Controles de reprodução do RepSound',
      notificationColor: AppColors.blue,
      androidNotificationIcon: 'drawable/ic_stat_music',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: true,
      preloadArtwork: false,
      fastForwardInterval: const Duration(seconds: 15),
      rewindInterval: const Duration(seconds: 15),
    );

    final media = MediaChannel();
    final cards = await SongCardCache.create(media);
    final settings = await SettingsController.create();
    cards.setArtworkSize(settings.artworkSize);
    settings.addListener(() => cards.setArtworkSize(settings.artworkSize));
    final profileStore = ProfileStore();
    final profile = PlaylistController(profileStore);
    final library = LibraryController(
      media: media,
      store: IndexStore(),
      cards: cards,
      settings: settings,
      profile: profile,
    );

    await profile.load();
    await library.load();

    final styles = StyleController(StyleStore());
    await styles.load();
    final daily = DailyController(DailyStore());
    await daily.load();
    await daily.ensureToday(library.songs, styles, profile);

    final player = PlayerController(
      cards: cards,
      profile: profile,
      settings: settings,
      library: library,
      queueStore: QueueStore(),
    );
    await player.restoreQueueFromDisk();
    final backup = BackupService(
      store: profileStore,
      settings: settings,
      playlists: profile,
      library: library,
    );
    backup.startAutoBackup();

    runApp(
      RepSoundApp(
        settings: settings,
        profile: profile,
        library: library,
        player: player,
        cards: cards,
        backup: backup,
        styles: styles,
        daily: daily,
      ),
    );
  } catch (error, stack) {
    debugPrint('Falha na inicialização do RepSound: $error');
    debugPrintStack(stackTrace: stack);
    runApp(StartupFailureApp(message: error.toString()));
  }
}
