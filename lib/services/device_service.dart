import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static const _deviceIdKey = 'device_uuid';
  static const _hasSeenAccountPromptKey = 'has_seen_account_prompt';
  static const _gamesPlayedSincePromptKey = 'games_since_prompt';

  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_deviceIdKey);
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, deviceId);
    }
    return deviceId;
  }

  static Future<bool> shouldShowAccountPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final gamesSincePrompt = prefs.getInt(_gamesPlayedSincePromptKey) ?? 0;
    return gamesSincePrompt >= 3;
  }

  static Future<void> incrementGamesPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_gamesPlayedSincePromptKey) ?? 0;
    await prefs.setInt(_gamesPlayedSincePromptKey, current + 1);
  }

  static Future<void> resetPromptCounter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_gamesPlayedSincePromptKey, 0);
    await prefs.setBool(_hasSeenAccountPromptKey, true);
  }

  static Future<void> markAccountCreated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenAccountPromptKey, true);
    await prefs.setInt(_gamesPlayedSincePromptKey, -999);
  }
}
