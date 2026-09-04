import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_app_lock/data/protected_app_model.dart';
import 'package:project_app_lock/dependency/dependency_manager.dart';
import 'package:project_app_lock/features/protected_apps/protected_apps_screen.dart';
import 'package:project_app_lock/features/protected_apps/protected_apps_store.dart';

import '../../fakes/fake_app_lock_gateway.dart';
import '../../fakes/fake_protected_app_selection_repository.dart';

void main() {
  late FakeProtectedAppSelectionRepository selectionRepository;

  setUp(() async {
    await sl.reset();
    final gateway = FakeAppLockGateway()
      ..apps = const <ProtectedAppModel>[
        ProtectedAppModel(packageId: 'com.chat', displayName: 'Chat'),
        ProtectedAppModel(packageId: 'com.video', displayName: 'Video'),
      ];
    selectionRepository = FakeProtectedAppSelectionRepository();
    sl.registerSingleton<ProtectedAppsStore>(
      ProtectedAppsStore(
        gateway: gateway,
        selectionRepository: selectionRepository,
      ),
    );
  });

  tearDown(() => sl.reset());

  testWidgets('searches and saves app selection', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProtectedAppsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'chat');
    await tester.pump();
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Video'), findsNothing);
    final saveButton = find.widgetWithText(FilledButton, 'Save apps to lock');
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
    expect(find.byIcon(Icons.lock_rounded), findsNothing);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(find.text('Focus shield active  •  1 selected'), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Chat, selected to lock',
      ),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
    expect(selectionRepository.values, isEmpty);

    await tester.tap(saveButton);
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    expect(selectionRepository.values, {'com.chat'});

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Apps to lock saved.'), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
  });
}
