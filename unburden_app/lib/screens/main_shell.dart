import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'home_screen.dart';
import 'conversations_screen.dart';
import 'posts_screen.dart';
import 'help_screen.dart';
import 'profile_screen.dart';

/// Persistent bottom navigation shell wrapping the 4 main tabs.
/// Uses IndexedStack to preserve tab state across switches.
class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void switchTab(int index) {
    if (index >= 0 && index < 5) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: const [
            HomeScreen(),
            ConversationsScreen(),
            PostsScreen(),
            HelpScreen(),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: AppColors.accent,
            unselectedItemColor: AppColors.slate,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            iconSize: 24,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                activeIcon: Icon(Icons.home_rounded),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_rounded),
                activeIcon: Icon(Icons.chat_bubble_rounded),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.eco_rounded),
                activeIcon: Icon(Icons.eco_rounded),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.health_and_safety_rounded),
                activeIcon: Icon(Icons.health_and_safety_rounded),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: '',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
