import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final path = GoRouterState.of(context).uri.path;
    final currentIndex = path == '/tasks'
        ? 1
        : path == '/apps-to-lock'
        ? 2
        : path == '/focus-session'
        ? 3
        : 0;
    return NavigationBar(
      selectedIndex: currentIndex,
      backgroundColor: colors.surface,
      indicatorColor: colors.primaryContainer,
      elevation: 0,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            context.goNamed('home');
          case 1:
            context.goNamed('tasks');
          case 2:
            context.goNamed('apps-to-lock');
          case 3:
            context.goNamed('focus-session');
        }
      },
      destinations: const <NavigationDestination>[
        NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.check_circle_outline),
          selectedIcon: Icon(Icons.check_circle),
          label: 'Tasks',
        ),
        NavigationDestination(
          icon: Icon(Icons.lock_outline),
          selectedIcon: Icon(Icons.lock),
          label: 'Apps',
        ),
        NavigationDestination(
          icon: Icon(Icons.lock_clock_outlined),
          selectedIcon: Icon(Icons.lock_clock),
          label: 'Session',
        ),
      ],
    );
  }
}
