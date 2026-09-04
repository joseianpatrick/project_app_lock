abstract interface class ProtectedAppSelectionRepository {
  Future<Set<String>> load();

  Future<void> save(Set<String> packageIds);
}
