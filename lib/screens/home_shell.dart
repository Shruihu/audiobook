import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'abs_library_screen.dart';
import 'library_screen.dart';
import 'player_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final localMode = context.watch<SettingsProvider>().localMode;

    final pages = <Widget>[
      if (localMode) const LibraryScreen(),
      const AbsLibraryScreen(),
      const SettingsScreen(),
    ];

    final destinations = <NavigationDestination>[
      if (localMode)
        const NavigationDestination(
          icon: Icon(Icons.folder_outlined),
          selectedIcon: Icon(Icons.folder),
          label: '本地',
        ),
      const NavigationDestination(
        icon: Icon(Icons.cloud_outlined),
        selectedIcon: Icon(Icons.cloud),
        label: '云端',
      ),
      const NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: '设置',
      ),
    ];

    // 防止切换时 index 越界
    final safeIndex = _currentIndex.clamp(0, pages.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: pages,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PlayerBar(),
          NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: (index) =>
                setState(() => _currentIndex = index),
            destinations: destinations,
          ),
        ],
      ),
    );
  }
}
