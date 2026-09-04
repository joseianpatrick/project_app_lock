import 'dart:async';

import 'package:project_app_lock/data/repository/protected_app_selection_repository.dart';

final class FakeProtectedAppSelectionRepository
    implements ProtectedAppSelectionRepository {
  FakeProtectedAppSelectionRepository([Set<String>? initial])
    : values = initial ?? <String>{};

  Set<String> values;
  int saveCalls = 0;
  int failSaveCount = 0;
  Completer<void>? saveGate;

  @override
  Future<Set<String>> load() async => Set<String>.of(values);

  @override
  Future<void> save(Set<String> packageIds) async {
    saveCalls += 1;
    final gate = saveGate;
    if (gate != null) await gate.future;
    if (failSaveCount > 0) {
      failSaveCount -= 1;
      throw StateError('save failed');
    }
    values = Set<String>.of(packageIds);
  }
}
