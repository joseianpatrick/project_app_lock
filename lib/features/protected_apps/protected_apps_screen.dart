import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:project_app_lock/data/protected_app_model.dart';
import 'package:project_app_lock/dependency/dependency_manager.dart';
import 'package:project_app_lock/features/protected_apps/protected_apps_store.dart';
import 'package:project_app_lock/shared/widgets/app_scaffold.dart';

class ProtectedAppsScreen extends StatefulWidget {
  const ProtectedAppsScreen({super.key});

  @override
  State<ProtectedAppsScreen> createState() => _ProtectedAppsScreenState();
}

class _ProtectedAppsScreenState extends State<ProtectedAppsScreen>
    with WidgetsBindingObserver {
  late final ProtectedAppsStore _store;
  bool _returningFromAuthorization = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store = sl<ProtectedAppsStore>()..initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _returningFromAuthorization) {
      _returningFromAuthorization = false;
      _store.initialize();
    }
  }

  Future<void> _requestAuthorization() async {
    _returningFromAuthorization = true;
    await _store.requestAuthorization();
  }

  Future<void> _saveSelection() async {
    final saved = await _store.saveSelection();
    if (!mounted || !saved) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Apps to lock saved.')));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Apps To Lock',
      onBackPressed: () => Navigator.maybePop(context),
      bottomNavigationBar: Observer(
        builder: (context) {
          if (_store.capability?.isAvailable != true) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            minimum: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _store.canSaveSelection ? _saveSelection : null,
                  icon: _store.isSavingSelection
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_outline),
                  label: Text(
                    _store.isSavingSelection ? 'Saving…' : 'Save apps to lock',
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
      body: Observer(
        builder: (context) {
          if (_store.isLoading) {
            return const _StateMessage(
              icon: Icons.hourglass_top,
              message: 'Loading installed apps…',
              progress: true,
            );
          }
          if (_store.errorMessage != null) {
            return _StateMessage(
              icon: Icons.error_outline,
              message: _store.errorMessage!,
              actionLabel: 'Try again',
              onAction: _store.initialize,
            );
          }
          final capability = _store.capability;
          if (capability != null && !capability.isAvailable) {
            return _StateMessage(
              icon: capability.authorizationRequired
                  ? Icons.admin_panel_settings_outlined
                  : Icons.mobile_off_outlined,
              message: capability.reason,
              actionLabel: capability.authorizationRequired
                  ? 'Grant access'
                  : null,
              onAction: capability.authorizationRequired
                  ? _requestAuthorization
                  : null,
            );
          }
          if (_store.isEmpty) {
            return _StateMessage(
              icon: Icons.apps_outlined,
              message: 'No eligible launchable apps were found.',
              actionLabel: 'Refresh',
              onAction: _store.loadApps,
            );
          }
          return CustomScrollView(
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Focus shield active  •  ${_store.selectedCount} selected',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: ListTile(
                          leading: Icon(
                            Icons.verified_user_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: const Text('Accessibility Guard'),
                          trailing: Text(
                            _store.capability?.isAvailable == true
                                ? 'ACTIVE'
                                : 'UNAVAILABLE',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          subtitle: Text(
                            _store.capability?.isAvailable == true
                                ? 'Service protects ${_store.selectedCount} selected app${_store.selectedCount == 1 ? '' : 's'} during focus sessions.'
                                : (_store.capability?.reason ??
                                      'Checking system access…'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SearchBar(
                        hintText: 'Search apps by name or package…',
                        leading: const Icon(Icons.search),
                        onChanged: _store.setSearchQuery,
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.builder(
                  itemCount:
                      _store.filteredApps.length +
                      (_store.selectionErrorMessage == null ? 0 : 1),
                  itemBuilder: (context, index) {
                    final selectionError = _store.selectionErrorMessage;
                    if (selectionError != null && index == 0) {
                      return Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: ListTile(
                          leading: const Icon(Icons.error_outline),
                          title: Text(selectionError),
                        ),
                      );
                    }
                    final appIndex = selectionError == null ? index : index - 1;
                    return _ProtectedAppTile(
                      app: _store.filteredApps[appIndex],
                      store: _store,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProtectedAppTile extends StatelessWidget {
  const _ProtectedAppTile({required this.app, required this.store});

  final ProtectedAppModel app;
  final ProtectedAppsStore store;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final isSelected = store.isSelected(app.packageId);
        return Card(
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (value) =>
                store.toggleSelection(app.packageId, selected: value ?? false),
            secondary: _AppIcon(app: app, isLocked: isSelected),
            title: Text(app.displayName),
            subtitle: Text(
              app.packageId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.app, required this.isLocked});

  final ProtectedAppModel app;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    try {
      final encoded = app.iconBase64;
      if (encoded != null) bytes = base64Decode(encoded);
    } catch (_) {
      bytes = null;
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: isLocked
          ? '${app.displayName}, selected to lock'
          : app.displayName,
      image: true,
      child: SizedBox.square(
        dimension: 48,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: bytes == null
                    ? const Icon(Icons.apps)
                    : Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
              ),
            ),
            if (isLocked)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.surface, width: 2),
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 12,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.progress = false,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool progress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (progress)
              const CircularProgressIndicator()
            else
              Icon(icon, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
