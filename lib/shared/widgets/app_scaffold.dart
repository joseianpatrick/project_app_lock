import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:project_app_lock/dependency/dependency_manager.dart';
import 'package:project_app_lock/shared/theme/theme_store.dart';

/// Shared page scaffold for screens hosted by [AppShell].
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.body,
    this.onBackPressed,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    super.key,
  });

  final String title;
  final Widget body;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final themeStore = sl.isRegistered<ThemeStore>() ? sl<ThemeStore>() : null;
    final themeActions = themeStore == null
        ? const <Widget>[]
        : <Widget>[
            Observer(
              builder: (_) => IconButton(
                tooltip: themeStore.isDark
                    ? 'Switch to light mode'
                    : 'Switch to dark mode',
                onPressed: themeStore.toggle,
                icon: Icon(
                  themeStore.isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
              ),
            ),
          ];
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: onBackPressed == null
            ? null
            : IconButton(
                tooltip: 'Go back',
                onPressed: onBackPressed,
                icon: const Icon(Icons.arrow_back),
              ),
        actions: <Widget>[...themeActions, ...?actions],
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
