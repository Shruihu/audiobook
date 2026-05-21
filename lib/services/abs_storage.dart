import 'package:shared_preferences/shared_preferences.dart';

import '../models/audiobookshelf_config.dart';

class AbsStorage {
  static const _key = 'abs_configs';

  static Future<List<AudioBookshelfConfig>> getSavedConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.map((s) => AudioBookshelfConfig.decode(s)).toList();
  }

  static Future<void> saveConfig(AudioBookshelfConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.add(config.encode());
    await prefs.setStringList(_key, list);
  }

  static Future<void> removeConfig(AudioBookshelfConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.removeWhere((s) {
      final c = AudioBookshelfConfig.decode(s);
      return c.serverUrl == config.serverUrl;
    });
    await prefs.setStringList(_key, list);
  }
}