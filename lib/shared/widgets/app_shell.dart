import 'package:flutter/material.dart';
import 'package:project_app_lock/shared/widgets/app_bottom_navigation.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const AppBottomNavigation(),
    );
  }
}
