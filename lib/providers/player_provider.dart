import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/audio_book.dart';
import '../models/audio_track.dart';
import '../services/audio_player_service.dart';
import '../services/folder_scanner.dart';
import '../services/library_storage.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayerService _playerService = AudioPlayerService();

  List<AudioBook> _books = [];
  bool _isScanning = false;

  AudioTrack? _currentTrack;
  AudioBook? _currentBook;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;

  Timer? _sleepTimer;
  Duration? _sleepDuration;
  DateTime? _sleepEndTime;

  List<AudioBook> get books => _books;
  bool get isScanning => _isScanning;
  AudioTrack? get currentTrack => _currentTrack;
  AudioBook? get currentBook => _currentBook;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  double get playbackSpeed => _playerService.playbackSpeed;
  AudioPlayerService get playerService => _playerService;
  bool get hasSleepTimer => _sleepTimer != null;
  Duration? get sleepDuration => _sleepDuration;
  Duration get sleepRemaining {
    if (_sleepEndTime == null) return Duration.zero;
    final remaining = _sleepEndTime!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  PlayerProvider() {
    // 不在这里初始化流，而是在 playBook/playTrack 时动态订阅
  }

  /// 订阅播放器的流（动态切换 just_audio 和 media_kit）
  void _subscribeToStreams() {
    // 取消旧的订阅
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playingSubscription?.cancel();

    // 订阅新的流
    _positionSubscription = _playerService.positionStream.listen((pos) {
      _position = pos;
      _syncCurrentTrack();
      if (!_isDisposed) notifyListeners();
    });

    _durationSubscription = _playerService.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      if (!_isDisposed) notifyListeners();
    });

    _playingSubscription = _playerService.playingStream.listen((playing) {
      _isPlaying = playing;
      _syncCurrentTrack();
      if (!_isDisposed) notifyListeners();
    });
  }

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;

  void _syncCurrentTrack() {
    if (_playerService.currentTrack != _currentTrack) {
      _currentTrack = _playerService.currentTrack;
    }
  }

  /// Load previously saved directories on startup.
  Future<void> loadSavedLibrary() async {
    _isScanning = true;
    notifyListeners();

    try {
      _books.clear();
      if (!kIsWeb) {
        final paths = await LibraryStorage.getSavedPaths();
        final List<AudioBook> allBooks = [];
        for (final path in paths) {
          allBooks.addAll(await FolderScanner.scanDirectory(path));
        }
        _books = allBooks;
      }
    } catch (e) {
      debugPrint('loadSavedLibrary error: $e');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }



  /// Add a directory (Android/desktop), scan it and persist.
  Future<void> addDirectory(String path) async {
    _isScanning = true;
    notifyListeners();

    try {
      debugPrint('Adding directory: $path');
      final newBooks = await FolderScanner.scanDirectory(path);
      debugPrint('Found ${newBooks.length} books in directory');
      if (newBooks.isNotEmpty) {
        _books.addAll(newBooks);
        await LibraryStorage.addPath(path);
        debugPrint('Directory added successfully');
      } else {
        debugPrint('No audio files found in directory');
      }
    } catch (e, stackTrace) {
      debugPrint('addDirectory error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Add books from picked files (Web platform).
  void addBooksFromFiles(List<PlatformFile> files) {
    final Map<String, List<AudioTrack>> grouped = {};

    for (final file in files) {
      if (!FolderScanner.isAudioFile(file.name)) continue;

      final dirName = _extractDirName(file);
      grouped.putIfAbsent(dirName, () => []);
      grouped[dirName]!.add(AudioTrack(
        filePath: file.name,
        title: FolderScanner.parseTitle(file.name),
        bookName: dirName,
        bytes: file.bytes,
      ));
    }

    for (final entry in grouped.entries) {
      final book = AudioBook(
        name: entry.key,
        folderPath: entry.key,
        tracks: entry.value..sort((a, b) => a.fileName.compareTo(b.fileName)),
      );
      _books.add(book);
    }

    notifyListeners();
  }

  String _extractDirName(PlatformFile file) {
    if (!kIsWeb) {
      try {
        final path = file.path;
        if (path != null) {
          final parts = path.split('/');
          if (parts.length >= 2) return parts[parts.length - 2];
        }
      } catch (_) {}
    }
    return '已选择的音频';
  }

  /// Remove a book from library.
  Future<void> removeBook(AudioBook book) async {
    _books.remove(book);
    if (!kIsWeb) {
      await LibraryStorage.removePath(book.folderPath);
    }
    notifyListeners();
  }

  Future<void> playBook(AudioBook book, {int startIndex = 0}) async {
    debugPrint('PlayerProvider.playBook called: ${book.name}, startIndex: $startIndex');
    _currentBook = book;
    try {
      debugPrint('Setting playlist with ${book.tracks.length} tracks');
      await _playerService.setPlaylist(book.tracks, startIndex: startIndex);
      _currentTrack = _playerService.currentTrack;
      _isPlaying = _playerService.isPlaying;
      debugPrint('Current track: ${_currentTrack?.title}, isPlaying: $_isPlaying');
      // 动态订阅正确的流
      _subscribeToStreams();
      notifyListeners();
      debugPrint('playBook completed successfully');
    } catch (e, stackTrace) {
      debugPrint('playBook error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> playTrack(AudioBook book, AudioTrack track) async {
    debugPrint('PlayerProvider.playTrack called: ${track.title}');
    _currentBook = book;
    final index = book.tracks.indexOf(track);
    debugPrint('Track index in book: $index');
    await _playerService.setPlaylist(book.tracks, startIndex: index);
    _currentTrack = _playerService.currentTrack;
    _isPlaying = _playerService.isPlaying;
    debugPrint('Current track after setPlaylist: ${_currentTrack?.title}, isPlaying: $_isPlaying');
    // 动态订阅正确的流
    _subscribeToStreams();
    notifyListeners();
    debugPrint('playTrack completed successfully');
  }

  Future<void> togglePlayPause() async {
    if (_playerService.isPlaying) {
      await _playerService.pause();
    } else {
      await _playerService.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _playerService.seek(position);
  }

  Future<void> next() async {
    await _playerService.next();
    _currentTrack = _playerService.currentTrack;
    notifyListeners();
  }

  Future<void> previous() async {
    await _playerService.previous();
    _currentTrack = _playerService.currentTrack;
    notifyListeners();
  }

  bool get hasCurrentTrack => _currentTrack != null;

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepDuration = duration;
    _sleepEndTime = null;

    if (duration != null) {
      _sleepEndTime = DateTime.now().add(duration);
      _sleepTimer = Timer(duration, () {
        _playerService.pause();
        _sleepTimer = null;
        _sleepDuration = null;
        _sleepEndTime = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void cancelSleepTimer() {
    setSleepTimer(null);
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    await _playerService.setVolume(_volume);
    notifyListeners();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await _playerService.setSpeed(speed);
    notifyListeners();
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _sleepTimer?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playingSubscription?.cancel();
    _playerService.dispose();
    super.dispose();
  }
}
