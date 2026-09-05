/// Emits the current value and every later revision of it.
///
/// Kept separate from the storage contracts so a repository only advertises a
/// stream when it actually has one to offer.
abstract interface class Watchable<T> {
  Stream<T> watch();
}

/// A keyed collection of [T] that can be observed as a whole.
abstract interface class Repository<T> implements Watchable<List<T>> {
  Future<T?> getById(String id);

  Future<void> set(String id, T value);

  Future<void> update(String id, Map<String, Object?> data);

  Future<void> delete(String id);

  String newId();
}

/// A single stored value of [T], replaced wholesale rather than keyed by id.
abstract interface class SingleValueRepository<T> {
  Future<T> load();

  Future<void> save(T value);
}
