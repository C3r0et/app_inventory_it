import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();

  // Beep for successful scan
  static Future<void> playSuccess() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/success.wav'));
    } catch (e) {
      print('Error playing success sound: $e');
    }
  }

  // Beep for duplicate scan (Double beep)
  static Future<void> playDuplicate() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/duplicate.wav'));
    } catch (e) {
      print('Error playing duplicate sound: $e');
    }
  }

  // Beep for error (Low pitch)
  static Future<void> playError() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/error.wav'));
    } catch (e) {
      print('Error playing error sound: $e');
    }
  }
}
