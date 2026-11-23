import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../discover/discover_screen.dart';
import '../home/home_screen.dart';
import '../library/library_screen.dart';
import '../profile/profile_screen.dart';
import '../read/read_screen.dart';

class AppShell extends StatefulWidget {
  final AppStrings s;
  final ThemeMode themeMode;
  final String lang;
  final int dailyGoal;
  final ValueChanged<ThemeMode> onTheme;
  final ValueChanged<String> onLang;
  final ValueChanged<int> onGoal;

  const AppShell({
    super.key,
    required this.s,
    required this.themeMode,
    required this.lang,
    required this.dailyGoal,
    required this.onTheme,
    required this.onLang,
    required this.onGoal,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final _readKey = GlobalKey<State<ReadScreen>>();

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final pages = [
      HomeScreen(
        s: s,
        onAddBook: () => setState(() => _index = 1),
        onImport: () => setState(() => _index = 2),
      ),
      LibraryScreen(s: s),
      ReadScreen(key: _readKey, s: s),
      DiscoverScreen(s: s),
      ProfileScreen(
        s: s,
        themeMode: widget.themeMode,
        lang: widget.lang,
        dailyGoal: widget.dailyGoal,
        onTheme: widget.onTheme,
        onLang: widget.onLang,
        onGoal: widget.onGoal,
      ),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: s.home),
          NavigationDestination(icon: const Icon(Icons.library_books_outlined), selectedIcon: const Icon(Icons.library_books), label: s.library),
          NavigationDestination(icon: const Icon(Icons.menu_book_outlined), selectedIcon: const Icon(Icons.menu_book), label: s.read),
          NavigationDestination(icon: const Icon(Icons.explore_outlined), selectedIcon: const Icon(Icons.explore), label: s.discover),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: s.profile),
        ],
      ),
    );
  }
}
