import 'package:shared_preferences/shared_preferences.dart';

class LibraryStorage {
  static const _key = 'audiobook_directories';

  static Future<List<String>> getSavedPaths() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  static Future<void> addPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final paths = prefs.getStringList(_key) ?? [];
    if (!paths.contains(path)) {
      paths.add(path);
      await prefs.setStringList(_key, paths);
    }
  }

  static Future<void> removePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final paths = prefs.getStringList(_key) ?? [];
    paths.remove(path);
    await prefs.setStringList(_key, paths);
  }
}
