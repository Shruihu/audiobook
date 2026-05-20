import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smb_connect/smb_connect.dart' if (dart.library.html) 'smb_stub.dart';

import '../models/smb_config.dart';

class SmbCacheManager {
  static final SmbCacheManager _instance = SmbCacheManager._internal();
  factory SmbCacheManager() => _instance;
  SmbCacheManager._internal();

  Directory? _cacheDir;
  final Map<String, String> _cachedFiles = {}; // smbUrl -> localPath

  Future<Directory> get _getCacheDir async {
    if (_cacheDir == null) {
      _cacheDir = await getTemporaryDirectory();
      _cacheDir = Directory('${_cacheDir!.path}/smb_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
    }
    return _cacheDir!;
  }

  /// 从 SMB 下载文件到本地缓存
  Future<String> downloadFile({
    required String smbUrl,
    required SmbConfig config,
    required String remotePath,
  }) async {
    // 检查是否已缓存
    if (_cachedFiles.containsKey(smbUrl)) {
      final cachedPath = _cachedFiles[smbUrl]!;
      if (await File(cachedPath).exists()) {
        debugPrint('Using cached file: $cachedPath');
        return cachedPath;
      }
    }

    SmbConnect? connection;
    try {
      debugPrint('Downloading from SMB: $remotePath');
      
      // 连接到 SMB
      connection = await SmbConnect.connectAuth(
        host: config.host,
        username: config.username ?? '',
        password: config.password ?? '',
        domain: config.domain ?? '',
      );

      // 构建完整路径
      final fullPath = '/${config.share}$remotePath';
      debugPrint('SMB full path: $fullPath');

      // 获取远程文件
      final remoteFile = await connection.file(fullPath);
      
      // 生成本地文件名（使用 URL 的 hash 避免冲突）
      final fileName = remotePath.split('/').last;
      final fileHash = smbUrl.hashCode.abs();
      final extension = fileName.contains('.') ? '.${fileName.split('.').last}' : '';
      final localFileName = 'smb_${fileHash.toString()}$extension';
      
      final cacheDir = await _getCacheDir;
      final localFile = File('${cacheDir.path}/$localFileName');

      // 使用流式读取下载文件
      debugPrint('Downloading to: ${localFile.path}');
      final sink = localFile.openWrite();
      
      try {
        // 设置超时（60秒）
        final streamFuture = connection.openRead(remoteFile).timeout(
          const Duration(seconds: 60),
        );
        
        final stream = await streamFuture;
        debugPrint('Stream opened, starting download...');
        
        int totalBytes = 0;
        int chunkCount = 0;
        final stopwatch = Stopwatch()..start();
        
        // 使用缓冲区批量写入，提高性能
        final buffer = <int>[];
        const bufferSize = 1024 * 1024; // 1MB 缓冲区
        
        await for (final chunk in stream) {
          buffer.addAll(chunk);
          totalBytes += chunk.length;
          chunkCount++;
          
          // 当缓冲区达到 1MB 时写入文件
          if (buffer.length >= bufferSize) {
            sink.add(Uint8List.fromList(buffer));
            buffer.clear();
          }
          
          // 每接收一个 chunk 或每 1MB 打印一次进度
          if (chunkCount % 10 == 0 || totalBytes % (1024 * 1024) == 0) {
            final elapsed = stopwatch.elapsedMilliseconds / 1000.0;
            final speed = totalBytes / elapsed / 1024; // KB/s
            debugPrint('Progress: ${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB '
                '(${totalBytes} bytes, $chunkCount chunks, ${speed.toStringAsFixed(1)} KB/s)');
          }
        }
        
        // 写入剩余数据
        if (buffer.isNotEmpty) {
          sink.add(Uint8List.fromList(buffer));
        }
        
        await sink.close();
        stopwatch.stop();
        final elapsed = stopwatch.elapsedMilliseconds / 1000.0;
        final speed = totalBytes / elapsed / 1024;
        debugPrint('Download complete: ${localFile.path} ($totalBytes bytes, $chunkCount chunks, '
            '${elapsed.toStringAsFixed(1)}s, ${speed.toStringAsFixed(1)} KB/s)');
      } catch (e) {
        await sink.close();
        rethrow;
      }

      // 缓存路径
      _cachedFiles[smbUrl] = localFile.path;

      return localFile.path;
    } catch (e, stackTrace) {
      debugPrint('Download error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    } finally {
      // 确保关闭连接
      await connection?.close();
    }
  }

  /// 清除所有缓存
  Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDir;
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
      _cachedFiles.clear();
      debugPrint('Cache cleared');
    } catch (e) {
      debugPrint('Clear cache error: $e');
    }
  }

  /// 获取缓存大小
  Future<int> getCacheSize() async {
    try {
      final cacheDir = await _getCacheDir;
      if (!await cacheDir.exists()) return 0;
      
      int totalSize = 0;
      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }
}
