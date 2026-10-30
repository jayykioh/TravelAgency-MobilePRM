import 'package:flutter/material.dart';

import 'ai_chat_screen.dart';
import 'hotel_bookings_screen.dart';
import 'hotel_home_screen.dart';
import 'hotels_map_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

/// Main navigation exposes every PRM393-scored feature from one Flutter flow.
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  static const pages = <Widget>[
    Home(),
    HotelsMapScreen(),
    HistoryScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: index, children: pages),
    floatingActionButton: FloatingActionButton.extended(
      heroTag: 'tripc-ai',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AiChatScreen()),
      ),
      icon: const Icon(Icons.auto_awesome),
      label: const Text('AI Chat'),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (value) => setState(() => index = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.hotel_outlined),
          selectedIcon: Icon(Icons.hotel),
          label: 'Hotels',
        ),
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map),
          label: 'Map',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Bookings',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_outlined),
          selectedIcon: Icon(Icons.notifications),
          label: 'Alerts',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    ),
  );
}
