import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:project_app_lock/dependency/dependency_manager.dart';
import 'package:project_app_lock/features/focus_session/focus_session_store.dart';
import 'package:project_app_lock/router/app_router.dart';
import 'package:project_app_lock/shared/theme/app_theme.dart';
import 'package:project_app_lock/shared/theme/theme_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DependencyManager().init();
  runApp(
    MainApp(
      router: AppRouter(sl<FocusSessionStore>()),
      themeStore: sl<ThemeStore>(),
    ),
  );
}

class MainApp extends StatefulWidget {
  const MainApp({required this.router, required this.themeStore, super.key});

  final AppRouter router;
  final ThemeStore themeStore;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  void dispose() {
    widget.router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) => MaterialApp.router(
        title: 'Focus Lock',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: widget.themeStore.isDark ? ThemeMode.dark : ThemeMode.light,
        routerConfig: widget.router.router,
      ),
    );
  }
}
