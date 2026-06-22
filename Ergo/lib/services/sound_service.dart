import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SoundService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playNotificationSound() async {
    try {
      // 1. Verify if the asset exists in the app bundle before invoking audioplayers.
      // This prevents native audio player threads from hanging/freezing on non-existent files.
      await rootBundle.load('assets/sounds/notification.mp3');

      // 2. Reset the player state before initiating playback to prevent channel deadlocks.
      await _player.stop();
      await _player.play(AssetSource('sounds/notification.mp3'));
      debugPrint('[SoundService] Played custom notification.mp3 successfully.');
    } catch (e) {
      debugPrint('[SoundService] Custom sound failed/not found ($e). Falling back to system alert.');
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (sysErr) {
        debugPrint('[SoundService] System sound playback error: $sysErr');
      }
    }
  }
}
