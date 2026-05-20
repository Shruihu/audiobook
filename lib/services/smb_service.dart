import 'package:smb_connect/smb_connect.dart' if (dart.library.html) 'smb_stub.dart';

import '../models/smb_config.dart';
import 'folder_scanner.dart';

class SmbFileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;

  SmbFileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
  });

  bool get isAudio => !isDirectory && FolderScanner.isAudioFile(name);
}

class SmbService {
  SmbConnect? _connection;
  SmbConfig? _config;

  bool get isConnected => _connection != null;
  SmbConfig? get config => _config;

  Future<void> connect(SmbConfig config) async {
    await disconnect();
    _connection = await SmbConnect.connectAuth(
      host: config.host,
      username: config.username ?? '',
      password: config.password ?? '',
      domain: config.domain ?? '',
    );
    _config = config;
  }

  Future<List<SmbFileItem>> listFiles(String path) async {
    if (_connection == null || _config == null) {
      throw StateError('Not connected to SMB server');
    }

    final fullPath = '/${_config!.share}$path';
    final folder = await _connection!.file(fullPath);
    final files = await _connection!.listFiles(folder);

    final items = <SmbFileItem>[];
    for (final file in files) {
      if (file.isDirectory()) {
        items.add(SmbFileItem(
          name: file.name,
          path: '$path/${file.name}',
          isDirectory: true,
        ));
      } else if (FolderScanner.isAudioFile(file.name)) {
        items.add(SmbFileItem(
          name: file.name,
          path: '$path/${file.name}',
          isDirectory: false,
          size: file.size,
        ));
      }
    }

    items.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    });

    return items;
  }

  Future<List<SmbFileItem>> listShares() async {
    if (_connection == null) {
      throw StateError('Not connected to SMB server');
    }

    final shares = await _connection!.listShares();
    return shares
        .where((s) => !s.name.endsWith('\$'))
        .map((s) => SmbFileItem(
              name: s.name,
              path: '/${s.name}',
              isDirectory: true,
            ))
        .toList();
  }

  Future<void> disconnect() async {
    await _connection?.close();
    _connection = null;
    _config = null;
  }
}
