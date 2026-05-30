import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/audio_book.dart';
import '../models/audio_track.dart';

class FolderScanner {
  static const supportedExtensions = {
    '.mp3',
    '.wma',
    '.m4a',
    '.flac',
    '.wav',
    '.ogg',
    '.aac',
    '.opus',
  };

  /// Scan a single directory for audio files, grouped by subfolder.
  /// If the directory itself contains audio files, they form one AudioBook.
  /// Subfolders with audio files each form their own AudioBook.
  static Future<List<AudioBook>> scanDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];

    final Map<String, List<AudioTrack>> folderTracks = {};

    try {
      final entities = await dir
          .list(recursive: true, followLinks: false)
          .where((e) => e is File && isAudioFile(e.path))
          .toList();

      for (final entity in entities) {
        final file = entity as File;
        final dirPath = file.parent.path;
        final dirName = file.parent.path.split('/').last;
        final fileName = file.path.split('/').last;
        final title = parseTitle(fileName);

        folderTracks.putIfAbsent(dirPath, () => []);
        folderTracks[dirPath]!.add(AudioTrack(
          filePath: file.path,
          title: title,
          bookName: dirName,
        ));
      }
    } catch (e) {
      debugPrint('FolderScanner error: $e');
    }

    final rootPath = dir.path;

    final books = folderTracks.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) {
          final bookName = _buildBookName(e.key, rootPath);
          return AudioBook(
            name: bookName,
            folderPath: e.key,
            tracks: e.value,
          );
        })
        .toList();

    books.sort((a, b) => a.name.compareTo(b.name));
    for (final book in books) {
      book.tracks.sort((a, b) => a.fileName.compareTo(b.fileName));
    }

    return books;
  }

  static bool isAudioFile(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) return false;
    final ext = path.substring(dotIndex).toLowerCase();
    return supportedExtensions.contains(ext);
  }

  static String parseTitle(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1) return fileName;
    var name = fileName.substring(0, dotIndex);
    // Remove patterns like "S01E01.", "S01E01 ", "EP01.", "E01-" etc.
    name = name.replaceFirst(RegExp(r'^[Ss]\d+[Ee]\d+[\s\.\-_]*'), '').trim();
    name = name.replaceFirst(RegExp(r'^[Ee][Pp]?\d+[\s\.\-_]*'), '').trim();
    // Remove leading numbers like "01 - ", "001_", "第01集"
    name = name.replaceFirst(RegExp(r'^[\d\s\-\._]+'), '').trim();
    name = name.replaceFirst(RegExp(r'^第\d+[集章节回][\s\.\-_]*'), '').trim();
    if (name.isEmpty) name = fileName.substring(0, dotIndex);
    return name;
  }

  /// Build book name from relative path between root and audio folder.
  /// e.g. root="/storage/emulated/0/三体广播剧", folder="/storage/emulated/0/三体广播剧/第一季"
  /// → "三体广播剧·第一季"
  /// If folder == root → use folder's own name.
  static String _buildBookName(String folderPath, String rootPath) {
    if (folderPath == rootPath) {
      return folderPath.split('/').last;
    }
    final relative = folderPath.substring(rootPath.length);
    final parts = relative.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return folderPath.split('/').last;
    final rootName = rootPath.split('/').last;
    return '$rootName·${parts.join('·')}';
  }
}
