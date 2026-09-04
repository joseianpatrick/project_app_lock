import 'package:mobx/mobx.dart';
import 'package:project_app_lock/data/app_lock_capability.dart';
import 'package:project_app_lock/data/protected_app_model.dart';
import 'package:project_app_lock/data/repository/protected_app_selection_repository.dart';
import 'package:project_app_lock/platform/app_lock/installed_apps_gateway.dart';

part 'protected_apps_store.g.dart';

class ProtectedAppsStore = ProtectedAppsStoreBase with _$ProtectedAppsStore;

abstract class ProtectedAppsStoreBase with Store {
  ProtectedAppsStoreBase({
    required this.gateway,
    required this.selectionRepository,
    this.minimumSaveDuration = const Duration(seconds: 1),
  });

  final InstalledAppsGateway gateway;
  final ProtectedAppSelectionRepository selectionRepository;
  final Duration minimumSaveDuration;

  @observable
  ObservableList<ProtectedAppModel> apps = ObservableList();

  @observable
  Set<String> selectedPackageIds = const <String>{};

  @observable
  Set<String> persistedPackageIds = const <String>{};

  @observable
  AppLockCapability? capability;

  @observable
  String searchQuery = '';

  @observable
  bool isLoading = false;

  @observable
  bool isSavingSelection = false;

  @observable
  String? errorMessage;

  @observable
  String? selectionErrorMessage;

  @computed
  int get selectedCount => selectedPackageIds.length;

  @computed
  bool get hasSelectionChanges =>
      selectedPackageIds.length != persistedPackageIds.length ||
      selectedPackageIds.any((id) => !persistedPackageIds.contains(id));

  @computed
  bool get canSaveSelection => hasSelectionChanges && !isSavingSelection;

  @computed
  bool get isEmpty => apps.isEmpty;

  @computed
  List<ProtectedAppModel> get filteredApps {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return apps.toList(growable: false);
    return apps
        .where((app) => app.displayName.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @action
  Future<void> initialize() async {
    isLoading = true;
    errorMessage = null;
    try {
      final saved = await selectionRepository.load();
      final status = await gateway.getCapability();
      runInAction(() {
        final snapshot = Set<String>.unmodifiable(saved);
        if (!hasSelectionChanges) selectedPackageIds = snapshot;
        persistedPackageIds = snapshot;
        capability = status;
      });
      if (status.isAvailable) await loadApps();
    } catch (_) {
      runInAction(() => errorMessage = 'Could not load apps. Try again.');
    } finally {
      runInAction(() => isLoading = false);
    }
  }

  @action
  Future<void> requestAuthorization() async {
    errorMessage = null;
    try {
      final status = await gateway.requestAuthorization();
      runInAction(() => capability = status);
    } catch (_) {
      runInAction(
        () => errorMessage = 'Could not open authorization settings.',
      );
    }
  }

  @action
  Future<void> loadApps() async {
    isLoading = true;
    errorMessage = null;
    try {
      final loaded = await gateway.getInstalledApps();
      final installedPackageIds = loaded.map((app) => app.packageId).toSet();
      final eligibleSelection = selectedPackageIds.intersection(
        installedPackageIds,
      );
      runInAction(() {
        apps = loaded.asObservable();
        if (eligibleSelection.length != selectedPackageIds.length) {
          selectedPackageIds = Set<String>.unmodifiable(eligibleSelection);
        }
      });
    } catch (_) {
      runInAction(() => errorMessage = 'Could not load installed apps.');
    } finally {
      runInAction(() => isLoading = false);
    }
  }

  @action
  void setSearchQuery(String value) => searchQuery = value;

  bool isSelected(String packageId) => selectedPackageIds.contains(packageId);

  @action
  void toggleSelection(String packageId, {required bool selected}) {
    final values = selectedPackageIds.toSet();
    selected ? values.add(packageId) : values.remove(packageId);
    selectedPackageIds = Set<String>.unmodifiable(values);
    selectionErrorMessage = null;
  }

  @action
  Future<bool> saveSelection() async {
    if (!canSaveSelection) return false;
    isSavingSelection = true;
    selectionErrorMessage = null;
    final snapshot = Set<String>.unmodifiable(selectedPackageIds);
    final stopwatch = Stopwatch()..start();
    try {
      await selectionRepository.save(snapshot);
      persistedPackageIds = snapshot;
      return true;
    } catch (_) {
      selectionErrorMessage = 'Could not save app selection. Try again.';
      return false;
    } finally {
      final remaining = minimumSaveDuration - stopwatch.elapsed;
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      isSavingSelection = false;
    }
  }
}
