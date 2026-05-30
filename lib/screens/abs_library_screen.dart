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
      title: _formatTrackTitle(t.title, t.index),
      bookName: item.title ?? 'Unknown',
      duration: t.duration != null ? Duration(milliseconds: (t.duration! * 1000).round()) : null,
      originalFileName: t.title.isNotEmpty ? t.title : null,
    )).toList();

    return AudioBook(
      name: item.title ?? 'Unknown',
      folderPath: _config?.serverUrl ?? '',
      tracks: tracks,
    );
  }

  /// 格式化音轨标题（仅用于显示，不影响播放）
  /// 匹配 S01E01、EP01、E01 等格式，提取集号和标题
  /// 例: "三体广播剧.S01E01 科学边界.wma" → "第1集 科学边界"
  static String _formatTrackTitle(String raw, int index) {
    try {
      if (raw.isEmpty) return '第${index + 1}集';
      // 去掉扩展名
      var title = raw.replaceFirst(RegExp(r'\.\w+$'), '');
      // 匹配 SxxExx 或 EPxx 或 Exx 格式
      final epMatch = RegExp(r'[.\s_-]*(?:S\d+)?(?:EP?)(\d+)[.\s_-]*(.*)', caseSensitive: false).firstMatch(title);
      if (epMatch != null) {
        final epNum = int.tryParse(epMatch.group(1) ?? '') ?? (index + 1);
        final epTitle = epMatch.group(2)?.trim() ?? '';
        if (epTitle.isNotEmpty) return '第$epNum集 $epTitle';
        return '第$epNum集';
      }
      return title;
    } catch (_) {
      return raw.isNotEmpty ? raw : '第${index + 1}集';
    }
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
          leading: _selectedLibrary != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () => setState(() => _selectedLibrary = null),
                )
              : null,
        ),
        body: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    if (_error != null) {
      final colorScheme = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_off_rounded,
                    size: 32, color: Colors.redAccent),
              ),
              const SizedBox(height: 20),
              Text('连接失败',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _selectedLibrary == null
                    ? _initialize
                    : () => _loadLibraryItems(_selectedLibrary!),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedLibrary == null) {
      return _buildLibraryList();
    }

    final items = _libraryItems[_selectedLibrary!.id] ?? [];
    if (items.isEmpty) {
      final colorScheme = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_music_outlined, size: 56, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('暂无书籍',
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 15)),
          ],
        ),
      );
    }

    return _buildBookList(items);
  }

  static const _libraryGradients = [
    [Color(0xFF7C4DFF), Color(0xFF448AFF)],
    [Color(0xFFFF6E40), Color(0xFFFFAB40)],
    [Color(0xFF69F0AE), Color(0xFF00B0FF)],
    [Color(0xFFFF80AB), Color(0xFFEA80FC)],
  ];

  Widget _buildLibraryList() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.4,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: _libraries.length,
      itemBuilder: (context, index) {
        final library = _libraries[index];
        final gradient = _libraryGradients[index % _libraryGradients.length];
        return GestureDetector(
          onTap: () => _loadLibraryItems(library),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  gradient[0].withAlpha(200),
                  gradient[1].withAlpha(200),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              children: [
                // Background icon
                Positioned(
                  right: -8,
                  bottom: -8,
                  child: Icon(
                    Icons.headphones_rounded,
                    size: 80,
                    color: Colors.white.withAlpha(25),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        library.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.55,
        crossAxisSpacing: 14,
        mainAxisSpacing: 18,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final trackCount = item.media?['numTracks'] as int? ?? 0;
        return _BookCard(
          item: item,
          trackCount: trackCount,
          onTap: () => _openBookDetail(item),
        );
      },
    );
  }

}

class _CoverPlaceholder extends StatelessWidget {
  final BorderRadius borderRadius;
  const _CoverPlaceholder({required this.borderRadius});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
      ),
      child: Icon(Icons.headphones_rounded, size: 40, color: colorScheme.onSurfaceVariant),
    );
  }
}

class _BookCard extends StatelessWidget {
  final AbsLibraryItem item;
  final int trackCount;
  final VoidCallback onTap;
  const _BookCard({required this.item, required this.trackCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withAlpha(30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.coverUrl != null && item.coverUrl!.isNotEmpty)
                      Image.network(
                        item.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stack) => _CoverPlaceholder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      )
                    else
                      const _CoverPlaceholder(borderRadius: BorderRadius.zero),
                    // Bottom gradient overlay
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withAlpha(180),
                            ],
                            stops: const [0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Track count badge
                    if (trackCount > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$trackCount集',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Title
          Text(
            item.title ?? '未知标题',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 3),
          // Author
          Text(
            item.author ?? '未知作者',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}