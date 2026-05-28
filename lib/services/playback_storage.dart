import 'package:shared_preferences/shared_preferences.dart';

class PlaybackState {
  final String bookName;
  final String folderPath;
  final String trackFilePath;
  final int positionMs;
  final double playbackSpeed;
  final double volume;
  final bool isAbs;

  const PlaybackState({
    required this.bookName,
    required this.folderPath,
    required this.trackFilePath,
    required this.positionMs,
    this.playbackSpeed = 1.0,
    this.volume = 1.0,
    this.isAbs = false,
  });

  Duration get position => Duration(milliseconds: positionMs);
}

class PlaybackStorage {
  static const _bookName = 'pb_bookName';
  static const _folderPath = 'pb_folderPath';
  static const _trackFilePath = 'pb_trackFilePath';
  static const _positionMs = 'pb_positionMs';
  static const _playbackSpeed = 'pb_playbackSpeed';
  static const _volume = 'pb_volume';
  static const _isAbs = 'pb_isAbs';

  static Future<void> save(PlaybackState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bookName, state.bookName);
    await prefs.setString(_folderPath, state.folderPath);
    await prefs.setString(_trackFilePath, state.trackFilePath);
    await prefs.setInt(_positionMs, state.positionMs);
    await prefs.setDouble(_playbackSpeed, state.playbackSpeed);
    await prefs.setDouble(_volume, state.volume);
    await prefs.setBool(_isAbs, state.isAbs);
  }

  static Future<void> savePosition(int positionMs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_positionMs, positionMs);
  }

  static Future<PlaybackState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final trackPath = prefs.getString(_trackFilePath);
    if (trackPath == null || trackPath.isEmpty) return null;

    return PlaybackState(
      bookName: prefs.getString(_bookName) ?? '',
      folderPath: prefs.getString(_folderPath) ?? '',
      trackFilePath: trackPath,
      positionMs: prefs.getInt(_positionMs) ?? 0,
      playbackSpeed: prefs.getDouble(_playbackSpeed) ?? 1.0,
      volume: prefs.getDouble(_volume) ?? 1.0,
      isAbs: prefs.getBool(_isAbs) ?? false,
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bookName);
    await prefs.remove(_folderPath);
    await prefs.remove(_trackFilePath);
    await prefs.remove(_positionMs);
    await prefs.remove(_playbackSpeed);
    await prefs.remove(_volume);
    await prefs.remove(_isAbs);
  }
}
