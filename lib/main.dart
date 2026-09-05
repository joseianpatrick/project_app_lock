import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project_app_lock/dependency/dependency_manager.dart';
import 'package:project_app_lock/features/focus_session/focus_session_store.dart';
import 'package:project_app_lock/router/app_router.dart';
import 'package:project_app_lock/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DependencyManager().init();
  runApp(MainApp(router: AppRouter(sl<FocusSessionStore>())));
}

class MainApp extends StatefulWidget {
  const MainApp({required this.router, super.key});

  final AppRouter router;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  static const String _themeModeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    unawaited(_loadThemeMode());
  }

  @override
  void dispose() {
    widget.router.dispose();
    super.dispose();
  }

  Future<void> _loadThemeMode() async {
    final savedMode = sl<SharedPreferences>().getString(_themeModeKey);
    if (!mounted || savedMode == null) return;
    final mode = ThemeMode.values.where((value) => value.name == savedMode);
    if (mode.isEmpty || mode.first == _themeMode) return;
    setState(() => _themeMode = mode.first);
  }

  void _toggleTheme() {
    final nextMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    setState(() {
      _themeMode = nextMode;
    });
    unawaited(sl<SharedPreferences>().setString(_themeModeKey, nextMode.name));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Focus Lock',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      builder: (context, child) => AppThemeScope(
        isDark: _themeMode == ThemeMode.dark,
        onToggle: _toggleTheme,
        child: child ?? const SizedBox.shrink(),
      ),
      routerConfig: widget.router.router,
    );
  }
}
