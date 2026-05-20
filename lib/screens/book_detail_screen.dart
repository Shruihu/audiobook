import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/audio_book.dart';
import '../models/audio_track.dart';
import '../providers/player_provider.dart';
import 'player_screen.dart';

class BookDetailScreen extends StatelessWidget {
  final AudioBook book;

  const BookDetailScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(book.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: '从头播放',
            onPressed: () async {
              debugPrint('Play book from start: ${book.name}');
              
              // 检查是否有 SMB 文件
              final hasSmbFiles = book.tracks.any((t) => t.isSmb);
              
              if (hasSmbFiles) {
                // 显示加载提示
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => AlertDialog(
                    title: const Text('正在准备播放'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text('正在从 NAS 下载音频文件...'),
                        const SizedBox(height: 8),
                        Text(
                          book.name,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              try {
                await context.read<PlayerProvider>().playBook(book);
                debugPrint('Book play initiated');
                
                // 关闭加载对话框（如果有）
                if (context.mounted && hasSmbFiles) {
                  Navigator.pop(context);
                }
                
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PlayerScreen()),
                  );
                }
              } catch (e) {
                debugPrint('Error playing book: $e');
                if (context.mounted) {
                  if (hasSmbFiles) {
                    Navigator.pop(context); // 关闭加载对话框
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('播放失败: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Consumer<PlayerProvider>(
        builder: (context, provider, _) {
          final currentTrack = provider.currentTrack;

          return ListView.builder(
            itemCount: book.tracks.length,
            itemBuilder: (context, index) {
              final track = book.tracks[index];
              final isCurrent = currentTrack != null &&
                  currentTrack.filePath == track.filePath;

              return _TrackTile(
                track: track,
                index: index,
                isPlaying: isCurrent && provider.isPlaying,
                isCurrent: isCurrent,
                onTap: () async {
                  debugPrint('Track tapped: ${track.title}');
                  
                  // 显示加载提示
                  if (!track.isSmb) {
                    // 本地文件直接播放
                    try {
                      await provider.playTrack(book, track);
                      debugPrint('Track play initiated, navigating to player screen');
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PlayerScreen()),
                        );
                      }
                    } catch (e) {
                      debugPrint('Error playing track: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('播放失败: $e')),
                        );
                      }
                    }
                  } else {
                    // SMB 文件显示下载提示
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => AlertDialog(
                        title: const Text('正在准备播放'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            const Text('正在从 NAS 下载音频文件...'),
                            const SizedBox(height: 8),
                            Text(
                              track.title,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                    
                    try {
                      await provider.playTrack(book, track);
                      
                      // 关闭加载对话框
                      if (context.mounted) {
                        Navigator.pop(context);
                        
                        // 跳转到播放器页面
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PlayerScreen()),
                        );
                      }
                    } catch (e) {
                      debugPrint('Error playing track: $e');
                      if (context.mounted) {
                        Navigator.pop(context); // 关闭加载对话框
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('播放失败: $e')),
                        );
                      }
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  final AudioTrack track;
  final int index;
  final bool isPlaying;
  final bool isCurrent;
  final VoidCallback onTap;

  const _TrackTile({
    required this.track,
    required this.index,
    required this.isPlaying,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isCurrent ? Colors.deepPurple : Colors.grey[300],
        child: isPlaying
            ? const Icon(Icons.equalizer, color: Colors.white, size: 18)
            : Text(
                '${index + 1}',
                style: TextStyle(
                  color: isCurrent ? Colors.white : Colors.grey[600],
                  fontSize: 13,
                ),
              ),
      ),
      title: Text(
        track.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          color: isCurrent ? Colors.deepPurple : null,
        ),
      ),
      subtitle: Text(
        track.fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      onTap: onTap,
    );
  }
}
