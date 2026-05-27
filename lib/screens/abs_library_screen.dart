import 'package:flutter/material.dart';

import '../models/audiobookshelf_config.dart';
import '../models/audio_book.dart';
import '../models/audio_track.dart';
import '../services/abs_storage.dart';
import '../services/audiobookshelf_service.dart';
import 'book_detail_screen.dart';

class AbsLibraryScreen extends StatefulWidget {
  final AudioBookshelfService? absService;
  final AudioBookshelfConfig? config;

  const AbsLibraryScreen({super.key, this.absService, this.config});

  @override
  State<AbsLibraryScreen> createState() => _AbsLibraryScreenState();
}

class _AbsLibraryScreenState extends State<AbsLibraryScreen> {
  AudioBookshelfService? _absService;
  AudioBookshelfConfig? _config;
  List<AbsLibrary> _libraries = [];
  final Map<String, List<AbsLibraryItem>> _libraryItems = {};
  AbsLibrary? _selectedLibrary;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // 如果传入了 service 和 config，直接使用
    if (widget.absService != null && widget.config != null) {
      _absService = widget.absService;
      _config = widget.config;
      await _loadLibraries();
    } else {
      // 否则从存储中加载配置并连接
      await _loadSavedConfig();
    }
  }

  Future<void> _loadSavedConfig() async {
    try {
      final configs = await AbsStorage.getSavedConfigs();
      if (configs.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = '请先在设置中添加 AudioBookshelf 连接';
        });
        return;
      }

      // 使用第一个保存的配置
      _config = configs.first;
      _absService = AudioBookshelfService();
      
      await _absService!.connect(_config!);
      await _loadLibraries();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '加载配置失败: $e';
      });
    }
  }

  @override
  void dispose() {
    _absService?.disconnect();
    super.dispose();
  }

  Future<void> _loadLibraries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final libraries = await _absService!.getLibraries();
      setState(() {
        _libraries = libraries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLibraryItems(AbsLibrary library) async {
    setState(() {
      _selectedLibrary = library;
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await _absService!.getLibraryItems(library.id);
      setState(() {
        _libraryItems[library.id] = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _openBookDetail(AbsLibraryItem item) async {
    // 显示加载指示器
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 获取书籍详情（包含完整音轨数据）
      final detailedItem = await _absService!.getLibraryItem(item.id);
      
      if (context.mounted) {
        Navigator.pop(context); // 关闭加载指示器
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookDetailScreen(
              book: _convertToAudioBook(detailedItem),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 关闭加载指示器
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载书籍失败：$e')),
        );
      }
    }
  }

  AudioBook _convertToAudioBook(AbsLibraryItem item) {
    final tracks = item.tracks.map((t) => AudioTrack(
      filePath: _absService?.appendToken(t.contentUrl) ?? t.contentUrl,
      title: t.title.isNotEmpty ? t.title : 'Track ${t.index + 1}',
      bookName: item.title ?? 'Unknown',
      duration: t.duration != null ? Duration(milliseconds: (t.duration! * 1000).round()) : null,
    )).toList();

    return AudioBook(
      name: item.title ?? 'Unknown',
      folderPath: _config?.serverUrl ?? '',
      tracks: tracks,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedLibrary == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedLibrary != null) {
          setState(() {
            _selectedLibrary = null;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_selectedLibrary?.name ?? '有声书库'),
          actions: _selectedLibrary != null
              ? [
                  IconButton(
                    icon: const Icon(Icons.home),
                    onPressed: () {
                      setState(() {
                        _selectedLibrary = null;
                      });
                    },
                  ),
                ]
              : null,
        ),
        body: _buildContent(),
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
              onPressed: _selectedLibrary == null
                  ? _loadLibraries
                  : () => _loadLibraryItems(_selectedLibrary!),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_selectedLibrary == null) {
      return _buildLibraryList();
    }

    final items = _libraryItems[_selectedLibrary!.id] ?? [];
    if (items.isEmpty) {
      return const Center(
        child: Text('暂无书籍', style: TextStyle(color: Colors.grey)),
      );
    }

    return _buildBookList(items);
  }

  Widget _buildLibraryList() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _libraries.length,
      itemBuilder: (context, index) {
        final library = _libraries[index];
        return Card(
          child: InkWell(
            onTap: () => _loadLibraryItems(library),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.library_books,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    library.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookList(List<AbsLibraryItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        // 从 media 中获取音轨数量
        final trackCount = item.media?['numTracks'] as int? ?? 0;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: _buildCover(item),
            title: Text(item.title ?? 'Unknown'),
            subtitle: Text('${item.author ?? 'Unknown'} · 共$trackCount集'),
            trailing: const Icon(Icons.play_circle_outline),
            onTap: () => _openBookDetail(item),
          ),
        );
      },
    );
  }

  Widget _buildCover(AbsLibraryItem item) {
    if (item.coverUrl != null && item.coverUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          item.coverUrl!,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox(
              width: 50,
              height: 50,
              child: Icon(Icons.book, size: 32),
            );
          },
        ),
      );
    }
    return const SizedBox(
      width: 50,
      height: 50,
      child: Icon(Icons.book, size: 32),
    );
  }
}