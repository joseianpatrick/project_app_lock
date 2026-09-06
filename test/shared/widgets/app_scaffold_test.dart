import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_app_lock/dependency/dependency_manager.dart';
import 'package:project_app_lock/shared/theme/theme_store.dart';
import 'package:project_app_lock/shared/widgets/app_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ThemeStore themeStore;

  setUp(() async {
    await sl.reset();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    themeStore = ThemeStore(await SharedPreferences.getInstance());
    sl.registerSingleton<ThemeStore>(themeStore);
  });

  tearDown(() async => sl.reset());

  testWidgets('theme action toggles the app theme through ThemeStore', (
    tester,
  ) async {
    await tester.pumpWidget(_ThemeHarness(themeStore: themeStore));

    expect(find.byTooltip('Switch to dark mode'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(AppScaffold))).brightness,
      Brightness.light,
    );

    await tester.tap(find.byTooltip('Switch to dark mode'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Switch to light mode'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(AppScaffold))).brightness,
      Brightness.dark,
    );
  });
}

class _ThemeHarness extends StatelessWidget {
  const _ThemeHarness({required this.themeStore});

  final ThemeStore themeStore;

  @override
  Widget build(BuildContext context) => Observer(
    builder: (_) => MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeStore.isDark ? ThemeMode.dark : ThemeMode.light,
      home: const AppScaffold(title: 'Test', body: SizedBox.shrink()),
    ),
  );
}
