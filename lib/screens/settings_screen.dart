import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../services/folder_scanner.dart';
import 'smb_connect_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          const _SectionHeader(title: '书库管理'),
          Consumer<PlayerProvider>(
            builder: (context, provider, _) {
              return ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('管理目录'),
                subtitle: Text('已添加 ${provider.books.length} 本有声书'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const _LibraryManageScreen()),
                  );
                },
              );
            },
          ),
          const Divider(),
          const _SectionHeader(title: '网络书库'),
          ListTile(
            leading: const Icon(Icons.lan),
            title: const Text('SMB/NAS 连接'),
            subtitle: const Text('从局域网 NAS 浏览有声书'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SmbConnectScreen()),
              );
            },
          ),
          const Divider(),
          const _SectionHeader(title: '播放设置'),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('播放速度'),
            subtitle: const Text('1.0x'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('定时关闭'),
            subtitle: const Text('未开启'),
            onTap: () {},
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}

class _LibraryManageScreen extends StatelessWidget {
  const _LibraryManageScreen();

  Future<void> _addDirectory(BuildContext context) async {
    final provider = context.read<PlayerProvider>();

    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions:
            FolderScanner.supportedExtensions.map((e) => e.substring(1)).toList(),
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        provider.addBooksFromFiles(result.files);
      }
    } else {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path != null) {
        await provider.addDirectory(path);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理目录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: kIsWeb ? '选择音频文件' : '添加目录',
            onPressed: () => _addDirectory(context),
          ),
        ],
      ),
      body: Consumer<PlayerProvider>(
        builder: (context, provider, _) {
          if (provider.books.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('暂无已添加目录', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _addDirectory(context),
                    icon: const Icon(Icons.add),
                    label: Text(kIsWeb ? '选择文件' : '添加目录'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: provider.books.length,
            itemBuilder: (context, index) {
              final book = provider.books[index];
              return ListTile(
                leading: const Icon(Icons.folder),
                title: Text(book.name),
                subtitle: Text('${book.trackCount} 集'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('确认移除'),
                        content: Text('从书库中移除"${book.name}"？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('移除', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      provider.removeBook(book);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
