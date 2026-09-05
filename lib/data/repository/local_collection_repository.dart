import 'dart:async';
import 'dart:convert';

import 'package:project_app_lock/data/repository/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// A [Repository] that keeps its whole collection in memory and mirrors it to
/// [SharedPreferences] as a JSON list.
///
/// The load/persist/emit machinery is identical for every entity we store this
/// way, so subclasses only describe what makes their entity different: how it
/// serialises, how it is ordered, and how a patch applies to it.
///
/// [preferences] may be null, in which case the collection stays in memory only.
abstract base class LocalCollectionRepository<T> implements Repository<T> {
  LocalCollectionRepository({Uuid? uuid, this.preferences})
    : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;
  final SharedPreferences? preferences;

  final Map<String, T> _items = <String, T>{};
  final StreamController<List<T>> _controller =
      StreamController<List<T>>.broadcast();
  bool _hasLoaded = false;

  /// The [SharedPreferences] key this collection is persisted under.
  String get storageKey;

  /// Plural entity name, used in persistence failure messages.
  String get entityLabel;

  String idOf(T value);

  T fromMap(Map<String, dynamic> map);

  Map<String, Object?> toMap(T value);

  /// Returns [value] stamped with [id], so a stored entity always agrees with
  /// the key it lives under.
  T withId(T value, String id);

  /// Applies a sparse [data] patch onto [current], leaving absent keys alone.
  T applyPatch(T current, Map<String, Object?> data);

  /// Ordering of the snapshot handed to listeners.
  int compare(T a, T b);

  List<T> get _snapshot {
    final values = _items.values.toList()..sort(compare);
    return List<T>.unmodifiable(values);
  }

  void _emit() => _controller.add(_snapshot);

  Future<void> _load() async {
    if (_hasLoaded) return;
    _hasLoaded = true;
    final encoded = preferences?.getString(storageKey);
    if (encoded == null) return;
    final decoded = jsonDecode(encoded) as List<dynamic>;
    _items
      ..clear()
      ..addEntries(
        decoded.whereType<Map<String, dynamic>>().map((map) {
          final item = fromMap(map);
          return MapEntry<String, T>(idOf(item), item);
        }),
      );
  }

  Future<void> _persist() async {
    final storage = preferences;
    if (storage == null) return;
    final saved = await storage.setString(
      storageKey,
      jsonEncode(_snapshot.map(toMap).toList()),
    );
    if (!saved) throw StateError('Could not persist $entityLabel.');
  }

  @override
  Stream<List<T>> watch() async* {
    await _load();
    yield _snapshot;
    yield* _controller.stream;
  }

  @override
  Future<T?> getById(String id) async {
    await _load();
    return _items[id];
  }

  @override
  Future<void> set(String id, T value) async {
    await _load();
    _items[id] = withId(value, id);
    await _persist();
    _emit();
  }

  @override
  Future<void> update(String id, Map<String, Object?> data) async {
    await _load();
    final current = _items[id];
    if (current == null) return;
    _items[id] = applyPatch(current, data);
    await _persist();
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    await _load();
    _items.remove(id);
    await _persist();
    _emit();
  }

  @override
  String newId() => _uuid.v4();

  void dispose() => _controller.close();
}
