import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;

import '../models/audio_track.dart' as models;
import 'smb_cache_manager.dart';

class _BytesAudioSource extends StreamAudioSource {
  final Uint8List _bytes;

  _BytesAudioSource(this._bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}

class AudioPlayerService {
  final AudioPlayer _justAudioPlayer = AudioPlayer();
  Player? _mediaKitPlayer;
  final SmbCacheManager _cacheManager = SmbCacheManager();

  models.AudioTrack? _currentTrack;
  final List<models.AudioTrack> _playlist = [];
  int _currentIndex = -1;

  bool _isDisposed = false;
  bool _autoAdvancing = false;
  bool _useMediaKit = false; // 标记当前是否使用 media_kit

  AudioPlayerService() {
    _justAudioPlayer.playerStateStream.listen((state) {
      if (!_useMediaKit && // 只在 just_audio 模式下监听
          state.processingState == ProcessingState.completed &&
          !_isDisposed &&
          !_autoAdvancing &&
          _currentIndex < _playlist.length - 1) {
        _autoAdvance();
      }
    });
  }

  void _autoAdvance() async {
    _autoAdvancing = true;
    await playAt(_currentIndex + 1);
    _autoAdvancing = false;
  }

  Stream<Duration> get positionStream {
    if (_useMediaKit && _mediaKitPlayer != null) {
      return _mediaKitPlayer!.stream.position;
    }
    return _justAudioPlayer.positionStream;
  }

  Stream<Duration?> get durationStream {
    if (_useMediaKit && _mediaKitPlayer != null) {
      return _mediaKitPlayer!.stream.duration;
    }
    return _justAudioPlayer.durationStream;
  }

  Stream<bool> get playingStream {
    if (_useMediaKit && _mediaKitPlayer != null) {
      return _mediaKitPlayer!.stream.playing;
    }
    return _justAudioPlayer.playingStream;
  }

  bool get isPlaying {
    if (_useMediaKit && _mediaKitPlayer != null) {
      return _mediaKitPlayer!.state.playing;
    }
    return _justAudioPlayer.playing;
  }

  models.AudioTrack? get currentTrack => _currentTrack;
  int get currentIndex => _currentIndex;
  List<models.AudioTrack> get playlist => List.unmodifiable(_playlist);

  Future<void> setPlaylist(List<models.AudioTrack> tracks, {int startIndex = 0}) async {
    _playlist.clear();
    _playlist.addAll(tracks);
    _currentIndex = startIndex.clamp(0, tracks.length - 1);
    await playAt(_currentIndex);
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    _currentIndex = index;
    _currentTrack = _playlist[index];

    if (kIsWeb) {
      await _playOnWeb(_currentTrack!);
      return;
    }

    try {
      debugPrint('Playing audio: ${_currentTrack!.playbackPath}');
      debugPrint('Track isSmb: ${_currentTrack!.isSmb}');
      
      String localPath;
      
      // 如果是 SMB 文件，先下载到本地缓存
      if (_currentTrack!.isSmb) {
        debugPrint('Detected SMB file, downloading to cache...');
        debugPrint('SMB URL: ${_currentTrack!.smbUrl}');
        debugPrint('Remote path: ${_currentTrack!.remotePath}');
        
        if (_currentTrack!.smbConfig == null) {
          throw Exception('SMB configuration is missing');
        }
        
        localPath = await _cacheManager.downloadFile(
          smbUrl: _currentTrack!.smbUrl!,
          config: _currentTrack!.smbConfig!,
          remotePath: _currentTrack!.remotePath!,
        );
        debugPrint('Downloaded to: $localPath');
      } else {
        // 本地文件直接使用
        localPath = _currentTrack!.filePath;
        debugPrint('Using local file: $localPath');
      }
      
      // 检测是否为 WMA 格式
      final isWma = localPath.toLowerCase().endsWith('.wma');
      debugPrint('File format: ${isWma ? "WMA" : "Non-WMA"}');
      
      if (isWma) {
        debugPrint('WMA format detected, using media_kit');
        _useMediaKit = true;
        
        // 停止 just_audio
        await _justAudioPlayer.stop();
        
        // 初始化或复用 media_kit player
        if (_mediaKitPlayer == null) {
          _mediaKitPlayer = Player();
          
          // 监听播放完成，自动下一曲
          _mediaKitPlayer!.stream.completed.listen((completed) {
            if (completed && !_isDisposed && !_autoAdvancing &&
                _currentIndex < _playlist.length - 1) {
              _autoAdvance();
            }
          });
        }
        
        // 播放
        final media = Media(localPath);
        await _mediaKitPlayer!.open(media, play: true);
        debugPrint('MediaKit playback started');
      } else {
        debugPrint('Using just_audio for non-WMA format');
        _useMediaKit = false;
        
        // 停止 media_kit
        await _mediaKitPlayer?.stop();
        
        // 使用 just_audio 播放
        await _justAudioPlayer.setFilePath(localPath);
        await _justAudioPlayer.play();
        debugPrint('just_audio playback started');
      }
    } catch (e, stackTrace) {
      debugPrint('Play error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _playOnWeb(models.AudioTrack track) async {
    if (track.bytes != null) {
      await _justAudioPlayer.setAudioSource(_BytesAudioSource(track.bytes!));
    } else {
      await _justAudioPlayer.setUrl(track.filePath);
    }
    await _justAudioPlayer.play();
  }

  Future<void> play() async {
    if (_useMediaKit && _mediaKitPlayer != null) {
      await _mediaKitPlayer!.play();
    } else {
      await _justAudioPlayer.play();
    }
  }

  Future<void> pause() async {
    if (_useMediaKit && _mediaKitPlayer != null) {
      await _mediaKitPlayer!.pause();
    } else {
      await _justAudioPlayer.pause();
    }
  }

  Future<void> seek(Duration position) async {
    if (_useMediaKit && _mediaKitPlayer != null) {
      await _mediaKitPlayer!.seek(position);
    } else {
      await _justAudioPlayer.seek(position);
    }
  }

  Future<void> next() async {
    if (_currentIndex < _playlist.length - 1) {
      await playAt(_currentIndex + 1);
    }
  }

  Future<void> previous() async {
    final pos = await getCurrentPosition();
    if (pos > const Duration(seconds: 3) && _currentIndex >= 0) {
      await seek(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      await playAt(_currentIndex - 1);
    }
  }

  Future<Duration> getCurrentPosition() async {
    if (_useMediaKit && _mediaKitPlayer != null) {
      return _mediaKitPlayer!.state.position;
    }
    return _justAudioPlayer.position;
  }

  Future<Duration?> getCurrentDuration() async {
    if (_useMediaKit && _mediaKitPlayer != null) {
      return _mediaKitPlayer!.state.duration;
    }
    return _justAudioPlayer.duration;
  }

  Future<void> dispose() async {
    _isDisposed = true;
    await _justAudioPlayer.dispose();
    await _mediaKitPlayer?.dispose();
  }

  Future<void> setVolume(double volume) async {
    if (_useMediaKit && _mediaKitPlayer != null) {
      await _mediaKitPlayer!.setVolume(volume * 100);
    } else {
      await _justAudioPlayer.setVolume(volume);
    }
  }

  double get volume => _justAudioPlayer.volume;

  Stream<double> get volumeStream => _justAudioPlayer.volumeStream;
}
