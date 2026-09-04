import 'dart:async';
import 'dart:convert';

import 'package:project_app_lock/data/lock_session_model.dart';
import 'package:project_app_lock/data/repository/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

final class LockSessionRepository implements Repository<LockSessionModel> {
  LockSessionRepository({Uuid? uuid, this.preferences})
    : _uuid = uuid ?? const Uuid(),
      super();

  static const String _storageKey = 'lock_sessions';
  final Uuid _uuid;
  final SharedPreferences? preferences;
  final Map<String, LockSessionModel> _sessions = {};
  bool _hasLoaded = false;
  final StreamController<List<LockSessionModel>> _controller =
      StreamController<List<LockSessionModel>>.broadcast();

  List<LockSessionModel> get _snapshot {
    final values = _sessions.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return List.unmodifiable(values);
  }

  Future<void> _load() async {
    if (_hasLoaded) return;
    _hasLoaded = true;
    final encoded = preferences?.getString(_storageKey);
    if (encoded == null) return;
    final decoded = jsonDecode(encoded) as List<dynamic>;
    _sessions
      ..clear()
      ..addEntries(
        decoded.whereType<Map<String, dynamic>>().map((map) {
          final session = LockSessionModel.fromMap(map);
          return MapEntry(session.id, session);
        }),
      );
  }

  Future<void> _persist() async {
    final storage = preferences;
    if (storage == null) return;
    final saved = await storage.setString(
      _storageKey,
      jsonEncode(_snapshot.map((session) => session.toMap()).toList()),
    );
    if (!saved) throw StateError('Could not persist lock sessions.');
  }

  void _emit() => _controller.add(_snapshot);

  @override
  Stream<List<LockSessionModel>> watch() async* {
    await _load();
    yield _snapshot;
    yield* _controller.stream;
  }

  @override
  Future<LockSessionModel?> getById(String id) async {
    await _load();
    return _sessions[id];
  }

  @override
  Future<void> set(String id, LockSessionModel value) async {
    await _load();
    _sessions[id] = value.copyWith(id: id);
    await _persist();
    _emit();
  }

  @override
  Future<void> update(String id, Map<String, Object?> data) async {
    await _load();
    final current = _sessions[id];
    if (current == null) return;
    _sessions[id] = current.copyWith(
      state: data['state'] as LockSessionState? ?? current.state,
    );
    await _persist();
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    await _load();
    _sessions.remove(id);
    await _persist();
    _emit();
  }

  @override
  String newId() => _uuid.v4();

  void dispose() => _controller.close();
}
