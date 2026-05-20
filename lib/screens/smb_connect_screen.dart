import 'package:flutter/material.dart';

import '../models/smb_config.dart';
import '../services/smb_service.dart';
import '../services/smb_storage.dart';
import 'smb_browser_screen.dart';

class SmbConnectScreen extends StatefulWidget {
  const SmbConnectScreen({super.key});

  @override
  State<SmbConnectScreen> createState() => _SmbConnectScreenState();
}

class _SmbConnectScreenState extends State<SmbConnectScreen> {
  List<SmbConfig> _savedConfigs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    final configs = await SmbStorage.getSavedConfigs();
    setState(() {
      _savedConfigs = configs;
      _isLoading = false;
    });
  }

  void _addNew() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _SmbEditScreen()),
    ).then((_) => _loadConfigs());
  }

  void _connectTo(SmbConfig config) async {
    final smbService = SmbService();
    _showConnecting();
    try {
      await smbService.connect(config);
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SmbBrowserScreen(
            smbService: smbService,
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

  Future<void> _deleteConfig(SmbConfig config) async {
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
      await SmbStorage.removeConfig(config);
      _loadConfigs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMB/NAS 连接'),
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
                      const Icon(Icons.lan, size: 64, color: Colors.grey),
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
                      leading: const Icon(Icons.storage),
                      title: Text(config.displayName),
                      subtitle: Text(config.username ?? '匿名访问'),
                      trailing: IconButton(
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteConfig(config),
                      ),
                      onTap: () => _connectTo(config),
                    );
                  },
                ),
    );
  }
}

class _SmbEditScreen extends StatefulWidget {
  const _SmbEditScreen();

  @override
  State<_SmbEditScreen> createState() => _SmbEditScreenState();
}

class _SmbEditScreenState extends State<_SmbEditScreen> {
  final _hostController = TextEditingController();
  final _shareController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _domainController = TextEditingController();
  bool _connecting = false;

  @override
  void dispose() {
    _hostController.dispose();
    _shareController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _domainController.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    final host = _hostController.text.trim();
    final share = _shareController.text.trim();
    if (host.isEmpty || share.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写服务器地址和共享名称')),
      );
      return;
    }

    setState(() => _connecting = true);

    final config = SmbConfig(
      host: host,
      share: share,
      username:
          _usernameController.text.trim().isEmpty ? null : _usernameController.text.trim(),
      password:
          _passwordController.text.isEmpty ? null : _passwordController.text,
      domain:
          _domainController.text.trim().isEmpty ? null : _domainController.text.trim(),
    );

    final smbService = SmbService();
    try {
      await smbService.connect(config);
      await SmbStorage.saveConfig(config);
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SmbBrowserScreen(
            smbService: smbService,
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
      appBar: AppBar(title: const Text('添加 SMB 连接')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: '服务器地址',
              hintText: '192.168.100.7',
              prefixIcon: Icon(Icons.computer),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _shareController,
            decoration: const InputDecoration(
              labelText: '共享名称',
              hintText: '有声书',
              prefixIcon: Icon(Icons.folder_shared),
            ),
          ),
          const SizedBox(height: 24),
          Text('认证信息（可选）',
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: '用户名',
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
          const SizedBox(height: 12),
          TextField(
            controller: _domainController,
            decoration: const InputDecoration(
              labelText: '域（一般留空）',
              prefixIcon: Icon(Icons.domain),
            ),
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
