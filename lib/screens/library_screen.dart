import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../models/audio_book.dart';
import '../providers/player_provider.dart';
import 'book_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlayerProvider>().loadSavedLibrary();
    });
  }

  Future<void> _pickFolder() async {
    // 请求存储权限
    if (Platform.isAndroid) {
      // Android 13+ 用 READ_MEDIA_AUDIO，低版本用 READ_EXTERNAL_STORAGE
      final audioStatus = await Permission.audio.request();
      if (!audioStatus.isGranted) {
        // 低版本 Android 回退到 storage 权限
        final storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted) {
          // 需要 MANAGE_EXTERNAL_STORAGE（Android 11+）
          final manageStatus = await Permission.manageExternalStorage.request();
          if (!manageStatus.isGranted && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('需要存储权限才能读取音频文件')),
            );
            return;
          }
        }
      }
    }

    final result = await FilePicker.getDirectoryPath(
      dialogTitle: '选择有声书文件夹',
    );
    if (result != null && mounted) {
      try {
        await context.read<PlayerProvider>().addDirectory(result);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('添加失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('本地书库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: '添加文件夹',
            onPressed: _pickFolder,
          ),
        ],
      ),
      body: Consumer<PlayerProvider>(
        builder: (context, provider, _) {
          if (provider.isScanning) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.books.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open, size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 16),
                    const Text('暂无本地有声书',
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 8),
                    const Text('点击右上角按钮添加有声书文件夹',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _pickFolder,
                      icon: const Icon(Icons.add),
                      label: const Text('添加文件夹'),
                    ),
                  ],
                ),
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              // 响应式列数：每项最小宽度 180px
              final crossAxisCount = (constraints.maxWidth / 180).floor().clamp(2, 6);
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                ),
                itemCount: provider.books.length,
                itemBuilder: (context, index) {
                  final book = provider.books[index];
                  return _LocalBookCard(
                    book: book,
                    onDelete: () => provider.removeBook(book),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookDetailScreen(book: book),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickFolder,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _LocalBookCard extends StatelessWidget {
  final AudioBook book;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _LocalBookCard({required this.book, required this.onDelete, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('确认删除'),
            content: Text('从列表中移除"${book.name}"？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirmed == true) onDelete();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover area
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(Icons.headphones_rounded,
                    size: 36, color: colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Book name
          Text(
            book.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          // Track count
          Text(
            '${book.trackCount} 集',
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
