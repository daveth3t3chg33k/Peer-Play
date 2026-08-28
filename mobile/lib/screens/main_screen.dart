import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../screens/home_screen.dart';
import '../screens/search_screen.dart';
import '../screens/vault_screen.dart';
import '../screens/settings_screen.dart';

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

  final _titles = const ['Home', 'Search', 'Vault', 'Settings'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _screens[_currentIndex]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.background,
          border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: AppTheme.background,
          selectedItemColor: AppTheme.text,
          unselectedItemColor: AppTheme.textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded, size: 22), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.search_rounded, size: 22), label: 'Search'),
            BottomNavigationBarItem(icon: Icon(Icons.download_rounded, size: 22), label: 'Vault'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded, size: 22), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}
