import 'package:shared_preferences/shared_preferences.dart';

import '../models/smb_config.dart';

class SmbStorage {
  static const _key = 'smb_configs';

  static Future<List<SmbConfig>> getSavedConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.map((s) => SmbConfig.decode(s)).toList();
  }

  static Future<void> saveConfig(SmbConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.add(config.encode());
    await prefs.setStringList(_key, list);
  }

  static Future<void> removeConfig(SmbConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.removeWhere((s) {
      final c = SmbConfig.decode(s);
      return c.host == config.host && c.share == config.share;
    });
    await prefs.setStringList(_key, list);
  }
}
