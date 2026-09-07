import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:project_app_lock/dependency/dependency_manager.dart';
import 'package:project_app_lock/features/focus_session/focus_session_store.dart';
import 'package:project_app_lock/shared/widgets/app_bottom_navigation.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final focusStore = sl.isRegistered<FocusSessionStore>()
        ? sl<FocusSessionStore>()
        : null;
    // Tabs are reached with `go`, so there is no stack to pop. System back
    // returns to the parent destination instead of exiting the app.
    return PopScope(
      canPop: path == '/',
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(path.startsWith('/tasks/') ? '/tasks' : '/');
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar: focusStore == null
            ? const AppBottomNavigation()
            : Observer(
                // Hidden while the session pins navigation to the task.
                builder: (_) =>
                    focusStore.activeSession?.policy?.lockToTaskScreen ?? false
                    ? const SizedBox.shrink()
                    : const AppBottomNavigation(),
              ),
      ),
    );
  }
}
