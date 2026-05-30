import 'package:flutter/material.dart';

import '../models/audiobookshelf_config.dart';
import '../services/abs_storage.dart';
import '../services/audiobookshelf_service.dart';
import 'abs_library_screen.dart';

class AudioBookshelfConnectScreen extends StatefulWidget {
  const AudioBookshelfConnectScreen({super.key});

  @override
  State<AudioBookshelfConnectScreen> createState() => _AbsConnectScreenState();
}

class _AbsConnectScreenState extends State<AudioBookshelfConnectScreen> {
  List<AudioBookshelfConfig> _savedConfigs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    final configs = await AbsStorage.getSavedConfigs();
    setState(() {
      _savedConfigs = configs;
      _isLoading = false;
    });
  }

  void _addNew() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _AbsEditScreen()),
    ).then((_) => _loadConfigs());
  }

  void _connectTo(AudioBookshelfConfig config) async {
    final absService = AudioBookshelfService();
    _showConnecting();
    try {
      await absService.connect(config);
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AbsLibraryScreen(
            absService: absService,
            config: config,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('连接失败: $e')),
      );
    }
  }

  void _showConnecting() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在连接...'),
          ],
        ),
      ),
    );
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
        title: const Text('AudioBookshelf 连接'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加连接',
            onPressed: _addNew,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedConfigs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('暂无已保存的连接',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _addNew,
                        icon: const Icon(Icons.add),
                        label: const Text('添加连接'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _savedConfigs.length,
                  itemBuilder: (context, index) {
                    final config = _savedConfigs[index];
                    return ListTile(
                      leading: const Icon(Icons.cloud),
                      title: Text(config.serverUrl),
                      subtitle: Text(config.username ?? '匿名'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteConfig(config),
                      ),
                      onTap: () => _connectTo(config),
                    );
                  },
                ),
    );
  }
}

class _AbsEditScreen extends StatefulWidget {
  const _AbsEditScreen();

  @override
  State<_AbsEditScreen> createState() => _AbsEditScreenState();
}

class _AbsEditScreenState extends State<_AbsEditScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '13378');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _connecting = false;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    final host = _hostController.text.trim();
    final port = _portController.text.trim();
    if (host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写服务器地址')),
      );
      return;
    }

    setState(() => _connecting = true);

    final serverUrl = 'http://$host${port.isNotEmpty ? ':$port' : ''}';
    final config = AudioBookshelfConfig(
      serverUrl: serverUrl,
      username: _usernameController.text.trim().isEmpty
          ? null
          : _usernameController.text.trim(),
      password: _passwordController.text.isEmpty
          ? null
          : _passwordController.text,
    );

    final absService = AudioBookshelfService();
    try {
      await absService.connect(config);
      await AbsStorage.saveConfig(config);
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AbsLibraryScreen(
            absService: absService,
            config: config,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('连接失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加 AudioBookshelf 连接')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: '服务器地址',
                    hintText: '192.168.100.7',
                    prefixIcon: Icon(Icons.cloud),
                  ),
                  keyboardType: TextInputType.url,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _portController,
                  decoration: const InputDecoration(
                    labelText: '端口',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('认证信息（可选）',
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: '用户名',
              hintText: 'admin',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: '密码',
              prefixIcon: Icon(Icons.lock),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _connecting ? null : _testAndSave,
            icon: _connecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link),
            label: Text(_connecting ? '连接中...' : '连接并保存'),
          ),
        ],
      ),
    );
  }
}