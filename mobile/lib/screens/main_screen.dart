import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'vault_screen.dart';
import 'settings_screen.dart';

/// Main screen with bottom navigation — Netflix-style
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    SearchScreen(),
    VaultScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.background,
          border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded, size: 22), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.search_rounded, size: 22), label: 'Search'),
            BottomNavigationBarItem(icon: Icon(Icons.download_rounded, size: 22), label: 'Downloads'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded, size: 22), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}
