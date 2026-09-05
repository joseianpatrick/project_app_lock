import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:project_app_lock/data/focus_behavior_settings_model.dart';
import 'package:project_app_lock/dependency/dependency_manager.dart';
import 'package:project_app_lock/features/focus_session/focus_session_store.dart';
import 'package:project_app_lock/features/settings/settings_store.dart';
import 'package:project_app_lock/shared/widgets/app_scaffold.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsStore _store;
  late final FocusSessionStore _sessionStore;

  @override
  void initState() {
    super.initState();
    _store = sl<SettingsStore>()..initialize();
    _sessionStore = sl<FocusSessionStore>()..initialize();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Focus behavior',
    onBackPressed: () => context.goNamed('home'),
    body: Observer(
      builder: (context) {
        if (_store.isLoading && _store.settings == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_store.settings == null) {
          return _SettingsError(
            message:
                _store.errorMessage ??
                'Focus behavior settings are unavailable.',
            onRetry: _store.initialize,
          );
        }
        return _SettingsContent(store: _store, sessionStore: _sessionStore);
      },
    ),
  );
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({required this.store, required this.sessionStore});

  final SettingsStore store;
  final FocusSessionStore sessionStore;

  @override
  Widget build(BuildContext context) {
    final settings = store.settings!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        Text(
          'Choose how your next focus session keeps you on task.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        _BehaviorSwitch(
          settingName: 'lockToTaskScreen',
          title: 'Lock navigation to task',
          subtitle:
              'Keep the active task open and hide normal navigation during focus.',
          value: settings.lockToTaskScreen,
          isSaving: store.savingSetting == 'lockToTaskScreen',
          onChanged: store.setLockToTaskScreen,
        ),
        _BehaviorSwitch(
          settingName: 'allowOtherApps',
          title: 'Allow other apps',
          subtitle: 'When enabled, only the apps you selected are restricted.',
          value: settings.allowOtherApps,
          isSaving: store.savingSetting == 'allowOtherApps',
          onChanged: store.setAllowOtherApps,
        ),
        _BehaviorSwitch(
          settingName: 'backButtonEnabled',
          title: 'Enable Back button',
          subtitle:
              'Allow the system Back action while a focus session is active.',
          value: settings.backButtonEnabled,
          isSaving: store.savingSetting == 'backButtonEnabled',
          onChanged: store.setBackButtonEnabled,
        ),
        if (store.errorMessage != null) ...<Widget>[
          const SizedBox(height: 12),
          _InlineError(message: store.errorMessage!),
        ],
        const SizedBox(height: 20),
        Observer(
          builder: (context) {
            final policy = store.activeSessionPolicy;
            if (policy == null || !sessionStore.hasActiveSession) {
              return const _SupportNote();
            }
            return _ActivePolicyCard(policy: policy);
          },
        ),
      ],
    );
  }
}

class _BehaviorSwitch extends StatelessWidget {
  const _BehaviorSwitch({
    required this.settingName,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.isSaving,
    required this.onChanged,
  });

  final String settingName;
  final String title;
  final String subtitle;
  final bool value;
  final bool isSaving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: isSaving ? null : onChanged,
      secondary: isSaving
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    ),
  );
}

class _ActivePolicyCard extends StatelessWidget {
  const _ActivePolicyCard({required this.policy});

  final FocusSessionPolicyModel policy;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Active session behavior',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'These read-only settings apply until the current session ends.',
          ),
          const SizedBox(height: 8),
          Text(
            'Navigation: ${policy.lockToTaskScreen ? 'locked' : 'available'}',
          ),
          Text(
            'Other apps: ${policy.allowOtherApps ? 'allowed' : 'restricted'}',
          ),
          Text(
            'Back button: ${policy.backButtonEnabled ? 'enabled' : 'disabled'}',
          ),
          const SizedBox(height: 8),
          const Text('Changes above apply to your next session.'),
        ],
      ),
    ),
  );
}

class _SupportNote extends StatelessWidget {
  const _SupportNote();

  @override
  Widget build(BuildContext context) => Card(
    child: const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'These preferences are saved for future sessions. App restrictions are available only where your device supports Focus Lock.',
      ),
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}

class _SettingsError extends StatelessWidget {
  const _SettingsError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
