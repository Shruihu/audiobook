import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/audiobookshelf_config.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/abs_storage.dart';
import 'abs_connect_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showPlaybackSpeedSheet(BuildContext context, PlayerProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('播放速度', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            for (final speed in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
              ListTile(
                title: Text('${speed}x'),
                trailing: provider.playbackSpeed == speed
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  provider.setPlaybackSpeed(speed);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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

  void _showThemeModeSheet(BuildContext context, ThemeProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('主题模式', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            for (final mode in ThemeMode.values)
              ListTile(
                leading: Icon(
                  {
                    ThemeMode.system: Icons.brightness_auto,
                    ThemeMode.light: Icons.light_mode,
                    ThemeMode.dark: Icons.dark_mode,
                  }[mode],
                ),
                title: Text({
                  ThemeMode.system: '跟随系统',
                  ThemeMode.light: '浅色模式',
                  ThemeMode.dark: '深色模式',
                }[mode]!),
                trailing: provider.themeMode == mode
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  provider.setThemeMode(mode);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          const _SectionHeader(title: '外观'),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              final labels = {
                ThemeMode.system: '跟随系统',
                ThemeMode.light: '浅色模式',
                ThemeMode.dark: '深色模式',
              };
              final icons = {
                ThemeMode.system: Icons.brightness_auto,
                ThemeMode.light: Icons.light_mode,
                ThemeMode.dark: Icons.dark_mode,
              };
              return ListTile(
                leading: Icon(icons[themeProvider.themeMode]),
                title: const Text('主题模式'),
                subtitle: Text(labels[themeProvider.themeMode]!),
                onTap: () => _showThemeModeSheet(context, themeProvider),
              );
            },
          ),
          const Divider(),
          const _SectionHeader(title: '网络书库'),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('AudioBookshelf'),
            subtitle: const Text('连接到 AudioBookshelf 服务器'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AudioBookshelfConnectScreen()),
              );
            },
          ),
          Consumer<PlayerProvider>(
            builder: (context, provider, _) {
              return ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('管理连接'),
                subtitle: const Text('查看和管理 AudioBookshelf 连接'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const _ConnectionManageScreen()),
                  );
                },
              );
            },
          ),
          const Divider(),
          const _SectionHeader(title: '播放设置'),
          Consumer<PlayerProvider>(
            builder: (context, provider, _) {
              return ListTile(
                leading: const Icon(Icons.speed),
                title: const Text('播放速度'),
                subtitle: Text('${provider.playbackSpeed.toStringAsFixed(1)}x'),
                onTap: () => _showPlaybackSpeedSheet(context, provider),
              );
            },
          ),
          Consumer<PlayerProvider>(
            builder: (context, provider, _) {
              return ListTile(
                leading: const Icon(Icons.timer),
                subtitle: Text(provider.hasSleepTimer
                    ? '${provider.sleepRemaining.inMinutes} 分钟后关闭'
                    : '未开启'),
                title: const Text('定时关闭'),
                onTap: () => _showSleepTimerSheet(context, provider),
              );
            },
          ),
          const Divider(),
          const _SectionHeader(title: '关于'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('版本'),
            subtitle: const Text('有声书播放器 v1.0.0'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ConnectionManageScreen extends StatefulWidget {
  const _ConnectionManageScreen();

  @override
  State<_ConnectionManageScreen> createState() => _ConnectionManageScreenState();
}

class _ConnectionManageScreenState extends State<_ConnectionManageScreen> {
  List<AudioBookshelfConfig> _configs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    final configs = await AbsStorage.getSavedConfigs();
    setState(() {
      _configs = configs;
      _isLoading = false;
    });
  }

  Future<void> _deleteConfig(AudioBookshelfConfig config) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('删除连接 "${config.displayName}"？'),
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
    if (confirm == true) {
      await AbsStorage.removeConfig(config);
      _loadConfigs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理连接'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _configs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('暂无已保存的连接', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AudioBookshelfConnectScreen()),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('添加连接'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _configs.length,
                  itemBuilder: (context, index) {
                    final config = _configs[index];
                    return ListTile(
                      leading: const Icon(Icons.cloud),
                      title: Text(config.serverUrl),
                      subtitle: Text(config.username ?? '匿名'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteConfig(config),
                      ),
                    );
                  },
                ),
    );
  }
}
