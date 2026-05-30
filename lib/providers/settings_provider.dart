import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _keyLocalMode = 'local_mode';

  bool _localMode = false;
  bool get localMode => _localMode;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _localMode = prefs.getBool(_keyLocalMode) ?? false;
    notifyListeners();
  }

  Future<void> setLocalMode(bool value) async {
    if (_localMode == value) return;
    _localMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLocalMode, value);
  }
}
