import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/audio_book.dart';
import '../models/audio_track.dart';
import '../models/smb_config.dart';
import '../providers/player_provider.dart';
import '../services/folder_scanner.dart';
import '../services/smb_service.dart';

class SmbBrowserScreen extends StatefulWidget {
  final SmbService smbService;
  final SmbConfig config;

  const SmbBrowserScreen({
    super.key,
    required this.smbService,
    required this.config,
  });

  @override
  State<SmbBrowserScreen> createState() => _SmbBrowserScreenState();
}

class _SmbBrowserScreenState extends State<SmbBrowserScreen> {
  List<SmbFileItem> _items = [];
  bool _isLoading = true;
  String? _error;
  String _currentPath = '';
  final List<String> _pathHistory = [];

  @override
  void initState() {
    super.initState();
    _loadDirectory('');
  }

  @override
  void dispose() {
    widget.smbService.disconnect();
    super.dispose();
  }

  Future<void> _loadDirectory(String path) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await widget.smbService.listFiles(path);
      setState(() {
        _items = items;
        _currentPath = path;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _enterDirectory(SmbFileItem item) {
    _pathHistory.add(_currentPath);
    _loadDirectory(item.path);
  }

  void _goBack() {
    if (_pathHistory.isNotEmpty) {
      final previous = _pathHistory.removeLast();
      _loadDirectory(previous);
    } else {
      Navigator.pop(context);
    }
  }

  void _addCurrentFolderAsBook() {
    final audioFiles = _items.where((i) => i.isAudio).toList();
    if (audioFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前文件夹没有音频文件')),
      );
      return;
    }

    final folderName = _currentPath.split('/').where((s) => s.isNotEmpty).lastOrNull ?? widget.config.share;

    final tracks = audioFiles.map((f) => AudioTrack(
      filePath: f.path,
      title: FolderScanner.parseTitle(f.name),
      bookName: folderName,
      smbUrl: widget.config.buildSmbUrl(f.path),
      smbConfig: widget.config, // 保存 SMB 配置
      remotePath: f.path, // 保存远程路径
    )).toList();

    final book = AudioBook(
      name: folderName,
      folderPath: 'smb://${widget.config.host}/${widget.config.share}$_currentPath',
      tracks: tracks,
    );

    context.read<PlayerProvider>().addSmbBook(book);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加 "$folderName"（${tracks.length} 集）')),
    );
  }

  String get _displayPath {
    if (_currentPath.isEmpty) return '/${widget.config.share}';
    return '/${widget.config.share}$_currentPath';
  }

  @override
  Widget build(BuildContext context) {
    final hasAudio = _items.any((i) => i.isAudio);

    return PopScope(
      canPop: _pathHistory.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.config.displayName),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack,
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text(
                _displayPath,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(child: _buildContent()),
          ],
        ),
        floatingActionButton: hasAudio && !_isLoading
            ? FloatingActionButton.extended(
                onPressed: _addCurrentFolderAsBook,
                icon: const Icon(Icons.library_add),
                label: const Text('添加为有声书'),
              )
            : null,
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('加载失败', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadDirectory(_currentPath),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Text('空文件夹', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return ListTile(
          leading: Icon(
            item.isDirectory
                ? Icons.folder
                : item.isAudio
                    ? Icons.audiotrack
                    : Icons.insert_drive_file,
            color: item.isDirectory
                ? Colors.amber[700]
                : item.isAudio
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
          ),
          title: Text(item.name),
          subtitle: item.isDirectory
              ? null
              : Text(_formatSize(item.size),
                  style: const TextStyle(fontSize: 12)),
          trailing: item.isDirectory
              ? const Icon(Icons.chevron_right)
              : null,
          onTap: item.isDirectory ? () => _enterDirectory(item) : null,
        );
      },
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
