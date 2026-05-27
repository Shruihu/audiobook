import 'dart:typed_data';

class AudioTrack {
  final String filePath;
  final String title;
  final Duration? duration;
  final String bookName;
  final Uint8List? bytes;
  final Map<String, String>? headers;

  AudioTrack({
    required this.filePath,
    required this.title,
    required this.bookName,
    this.duration,
    this.bytes,
    this.headers,
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
