import 'package:flutter_test/flutter_test.dart';
import 'package:project_app_lock/data/protected_app_model.dart';
import 'package:project_app_lock/features/protected_apps/protected_apps_store.dart';

import '../../fakes/fake_app_lock_gateway.dart';
import '../../fakes/fake_protected_app_selection_repository.dart';

void main() {
  late FakeAppLockGateway gateway;
  late FakeProtectedAppSelectionRepository selectionRepository;
  late ProtectedAppsStore store;

  setUp(() {
    gateway = FakeAppLockGateway()
      ..apps = const <ProtectedAppModel>[
        ProtectedAppModel(packageId: 'com.chat', displayName: 'Chat'),
        ProtectedAppModel(packageId: 'com.video', displayName: 'Video'),
      ];
    selectionRepository = FakeProtectedAppSelectionRepository({'com.chat'});
    store = ProtectedAppsStore(
      gateway: gateway,
      selectionRepository: selectionRepository,
      minimumSaveDuration: Duration.zero,
    );
  });

  test('initialize loads apps and saved selection', () async {
    await store.initialize();

    expect(store.apps, hasLength(2));
    expect(store.selectedCount, 1);
    expect(store.selectedPackageIds, {'com.chat'});
    expect(store.hasSelectionChanges, isFalse);
    expect(store.canSaveSelection, isFalse);
  });

  test('search is case insensitive and does not mutate selection', () async {
    await store.initialize();
    store.setSearchQuery('vID');

    expect(store.filteredApps.single.displayName, 'Video');
    expect(store.selectedPackageIds, {'com.chat'});
  });

  test('toggle changes draft without persisting', () async {
    await store.initialize();

    store.toggleSelection('com.video', selected: true);

    expect(store.selectedPackageIds, {'com.chat', 'com.video'});
    expect(selectionRepository.values, {'com.chat'});
    expect(store.hasSelectionChanges, isTrue);
    expect(store.canSaveSelection, isTrue);
  });

  test('save persists draft and disables save until another change', () async {
    await store.initialize();
    store.toggleSelection('com.video', selected: true);

    expect(await store.saveSelection(), isTrue);

    expect(selectionRepository.values, {'com.chat', 'com.video'});
    expect(store.hasSelectionChanges, isFalse);
    expect(store.canSaveSelection, isFalse);
    expect(await store.saveSelection(), isFalse);
  });

  test('failed save keeps draft available for retry', () async {
    await store.initialize();
    store.toggleSelection('com.video', selected: true);
    selectionRepository.failSaveCount = 1;

    expect(await store.saveSelection(), isFalse);

    expect(store.selectedPackageIds, {'com.chat', 'com.video'});
    expect(selectionRepository.values, {'com.chat'});
    expect(store.canSaveSelection, isTrue);
    expect(store.selectionErrorMessage, isNotNull);
  });

  test('reinitialize does not overwrite an unsaved draft', () async {
    await store.initialize();
    store.toggleSelection('com.video', selected: true);

    await store.initialize();

    expect(store.selectedPackageIds, {'com.chat', 'com.video'});
    expect(store.canSaveSelection, isTrue);
  });

  test('uninstalled selections are removed from draft before save', () async {
    selectionRepository.values.add('missing.app');

    await store.initialize();

    expect(store.selectedPackageIds, {'com.chat'});
    expect(selectionRepository.values, {'com.chat', 'missing.app'});
    expect(store.canSaveSelection, isTrue);

    await store.saveSelection();
    expect(selectionRepository.values, {'com.chat'});
  });
}
