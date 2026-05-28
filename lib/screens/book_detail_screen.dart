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
              try {
                await context.read<PlayerProvider>().playBook(book);
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PlayerScreen()),
                  );
                }
              } catch (e) {
                debugPrint('Error playing book: $e');
                if (context.mounted) {
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
                  try {
                    await provider.playTrack(book, track);
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
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isCurrent
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
        child: isPlaying
            ? Icon(Icons.equalizer, color: colorScheme.onPrimary, size: 18)
            : Text(
                '${index + 1}',
                style: TextStyle(
                  color: isCurrent ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
      ),
      title: Text(
        track.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
          color: isCurrent ? colorScheme.primary : null,
        ),
      ),
      subtitle: Text(
        track.fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
      ),
      onTap: onTap,
    );
  }
}
