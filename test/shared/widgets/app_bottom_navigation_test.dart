import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:project_app_lock/shared/widgets/app_bottom_navigation.dart';

void main() {
  late GoRouter router;

  setUp(() {
    router = GoRouter(
      initialLocation: '/focus-session',
      routes: <RouteBase>[
        ShellRoute(
          builder: (context, state, child) => Scaffold(
            body: child,
            bottomNavigationBar: const AppBottomNavigation(),
          ),
          routes: <RouteBase>[
            GoRoute(
              path: '/',
              name: 'home',
              builder: (context, state) => const Text('Home page'),
            ),
            GoRoute(
              path: '/tasks',
              name: 'tasks',
              builder: (context, state) => const Text('Tasks page'),
            ),
            GoRoute(
              path: '/apps-to-lock',
              name: 'apps-to-lock',
              builder: (context, state) => const Text('Apps page'),
            ),
            GoRoute(
              path: '/focus-session',
              name: 'focus-session',
              builder: (context, state) => const Text('Session page'),
            ),
          ],
        ),
      ],
    );
  });

  tearDown(() => router.dispose());

  testWidgets('shows and navigates the Session destination', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Session'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    expect(find.text('Tasks page'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
  });
}
