import 'dart:typed_data';

class AudioTrack {
  final String filePath;
  final String title;
  final Duration? duration;
  final String bookName;
  final Uint8List? bytes;

  AudioTrack({
    required this.filePath,
    required this.title,
    required this.bookName,
    this.duration,
    this.bytes,
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
