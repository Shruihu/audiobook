import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';

class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        if (!provider.hasCurrentTrack) {
          return const SizedBox.shrink();
        }

        final colorScheme = Theme.of(context).colorScheme;
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlayerScreen()),
            );
          },
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                // Mini progress indicator
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    provider.isPlaying ? Icons.headphones : Icons.headphones_outlined,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                // Track info
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.currentTrack!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        provider.currentBook?.name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                // Play/pause button
                IconButton(
                  icon: Icon(
                    provider.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    size: 36,
                    color: colorScheme.primary,
                  ),
                  onPressed: () => provider.togglePlayPause(),
                ),
                // Close button
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 22,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => provider.stop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.read<PlayerProvider>().currentBook?.name ?? '播放器'),
      ),
      body: Consumer<PlayerProvider>(
        builder: (context, provider, _) {
          if (!provider.hasCurrentTrack) {
            return const Center(child: Text('没有正在播放的曲目'));
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Album art placeholder
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withAlpha(40),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.headphones_rounded,
                      size: 80,
                      color: colorScheme.primary.withAlpha(150),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Title
                Text(
                  provider.currentTrack!.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  provider.currentBook?.name ?? '',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                // Progress bar
                Column(
                  children: [
                    Slider(
                      value: provider.duration.inMilliseconds > 0
                          ? (provider.position.inMilliseconds /
                                  provider.duration.inMilliseconds)
                              .clamp(0.0, 1.0)
                          : 0.0,
                      onChanged: (value) {
                        final seekPos = Duration(
                          milliseconds:
                              (value * provider.duration.inMilliseconds)
                                  .round(),
                        );
                        provider.seek(seekPos);
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(provider.position)),
                          Text(_formatDuration(provider.duration)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous, size: 36),
                      onPressed: () => provider.previous(),
                    ),
                    const SizedBox(width: 20),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      child: IconButton(
                        icon: Icon(
                          provider.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 36,
                          color: Colors.white,
                        ),
                        onPressed: () => provider.togglePlayPause(),
                      ),
                    ),
                    const SizedBox(width: 20),
                    IconButton(
                      icon: const Icon(Icons.skip_next, size: 36),
                      onPressed: () => provider.next(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Volume control
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      Icon(Icons.volume_down, color: colorScheme.onSurfaceVariant),
                      Expanded(
                        child: Slider(
                          value: provider.volume,
                          onChanged: (value) => provider.setVolume(value),
                          activeColor: colorScheme.primary,
                        ),
                      ),
                      Icon(Icons.volume_up, color: colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Sleep timer
                TextButton.icon(
                  icon: Icon(
                    provider.hasSleepTimer ? Icons.timer : Icons.timer_outlined,
                    size: 18,
                    color: provider.hasSleepTimer
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  label: Text(
                    provider.hasSleepTimer
                        ? '${provider.sleepRemaining.inMinutes} 分钟后关闭'
                        : '定时关闭',
                    style: TextStyle(
                      color: provider.hasSleepTimer
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onPressed: () => _showSleepTimerSheet(context, provider),
                ),
                const Spacer(),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  void _showSleepTimerSheet(BuildContext context, PlayerProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('定时关闭', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('15 分钟'),
              onTap: () {
                provider.setSleepTimer(const Duration(minutes: 15));
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('30 分钟'),
              onTap: () {
                provider.setSleepTimer(const Duration(minutes: 30));
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('45 分钟'),
              onTap: () {
                provider.setSleepTimer(const Duration(minutes: 45));
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('1 小时'),
              onTap: () {
                provider.setSleepTimer(const Duration(hours: 1));
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('2 小时'),
              onTap: () {
                provider.setSleepTimer(const Duration(hours: 2));
                Navigator.pop(ctx);
              },
            ),
            if (provider.hasSleepTimer)
              ListTile(
                leading: const Icon(Icons.timer_off, color: Colors.red),
                title: const Text('取消定时', style: TextStyle(color: Colors.red)),
                onTap: () {
                  provider.cancelSleepTimer();
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
