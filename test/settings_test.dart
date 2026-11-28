import 'package:flutter_test/flutter_test.dart';
import 'package:repsound/data/models.dart';
import 'package:repsound/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('artworkSize acompanha o perfil de qualidade', () async {
    final settings = await SettingsController.create();
    expect(settings.artworkSize, 320);

    settings.setPlaybackQuality(PlaybackQuality.high);
    expect(settings.artworkSize, 512);

    settings.setPlaybackQuality(PlaybackQuality.saver);
    expect(settings.artworkSize, 192);
  });

  test('qualidade e animações persistem entre instâncias', () async {
    final settings = await SettingsController.create();
    settings.setPlaybackQuality(PlaybackQuality.saver);
    settings.setAnimations(false);
    await Future<void>.delayed(Duration.zero);

    final reloaded = await SettingsController.create();
    expect(reloaded.playbackQuality, PlaybackQuality.saver);
    expect(reloaded.animations, isFalse);
    expect(reloaded.artworkSize, 192);
  });

  test('perfil econômico descreve o comportamento real', () {
    expect(
      PlaybackQuality.saver.description,
      contains('192 px'),
    );
    expect(
      PlaybackQuality.high.description,
      contains('512 px'),
    );
    expect(
      PlaybackQuality.auto.description,
      contains('320 px'),
    );
  });

  test('toque na capa vem ligado com passo de 10 s', () async {
    final settings = await SettingsController.create();
    expect(settings.tapToSeek, isTrue);
    expect(settings.seekStepSeconds, 10);
  });

  test('passo do toque respeita limites e persiste', () async {
    final settings = await SettingsController.create();
    settings.setSeekStepSeconds(1);
    expect(settings.seekStepSeconds, 5);
    settings.setSeekStepSeconds(999);
    expect(settings.seekStepSeconds, 60);
    settings.setSeekStepSeconds(30);
    settings.setTapToSeek(false);
    await Future<void>.delayed(Duration.zero);

    final reloaded = await SettingsController.create();
    expect(reloaded.seekStepSeconds, 30);
    expect(reloaded.tapToSeek, isFalse);
  });

  test('toque e passo entram no backup JSON', () async {
    final settings = await SettingsController.create();
    settings.setTapToSeek(false);
    settings.setSeekStepSeconds(15);
    final json = settings.toJson();
    expect(json['tapToSeek'], isFalse);
    expect(json['seekStepSeconds'], 15);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final restored = await SettingsController.create();
    await restored.applyJson(<String, dynamic>{
      ...json,
      'tapToSeek': true,
      'seekStepSeconds': 5,
    });
    expect(restored.tapToSeek, isTrue);
    expect(restored.seekStepSeconds, 5);
  });
}
