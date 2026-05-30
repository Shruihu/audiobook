import 'dart:typed_data';

class AudioTrack {
  final String filePath;
  final String title;
  final Duration? duration;
  final String bookName;
  final Uint8List? bytes;
  final Map<String, String>? headers;
  final String? originalFileName; // 原始文件名，用于格式检测

  AudioTrack({
    required this.filePath,
    required this.title,
    required this.bookName,
    this.duration,
    this.bytes,
    this.headers,
    this.originalFileName,
  });

  String get fileName => filePath.split('/').last;

  String get playbackPath => filePath;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioTrack && playbackPath == other.playbackPath;

  @override
  int get hashCode => playbackPath.hashCode;
}
