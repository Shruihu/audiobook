import 'dart:typed_data';

import 'smb_config.dart';

class AudioTrack {
  final String filePath;
  final String title;
  final Duration? duration;
  final String bookName;
  final Uint8List? bytes;
  final String? smbUrl;
  final SmbConfig? smbConfig; // SMB 配置信息
  final String? remotePath; // 远程文件路径（相对于 share）

  AudioTrack({
    required this.filePath,
    required this.title,
    required this.bookName,
    this.duration,
    this.bytes,
    this.smbUrl,
    this.smbConfig,
    this.remotePath,
  });

  bool get isSmb => smbUrl != null && smbConfig != null && remotePath != null;

  String get fileName => filePath.split('/').last;

  String get playbackPath => smbUrl ?? filePath;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioTrack && playbackPath == other.playbackPath;

  @override
  int get hashCode => playbackPath.hashCode;
}
