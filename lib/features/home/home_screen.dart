import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:project_app_lock/data/lock_session_model.dart';
import 'package:project_app_lock/dependency/dependency_manager.dart';
import 'package:project_app_lock/features/focus_session/focus_session_store.dart';
import 'package:project_app_lock/features/protected_apps/protected_apps_store.dart';
import 'package:project_app_lock/features/tasks/task_store.dart';
import 'package:project_app_lock/shared/widgets/app_scaffold.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TaskStore _taskStore;
  late final ProtectedAppsStore _appsStore;
  late final FocusSessionStore _sessionStore;

  @override
  void initState() {
    super.initState();
    _taskStore = sl<TaskStore>()..initialize();
    _appsStore = sl<ProtectedAppsStore>()..initialize();
    _sessionStore = sl<FocusSessionStore>()..initialize();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Dashboard',
      body: CustomScrollView(
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            sliver: SliverList.list(
              children: <Widget>[
                const _FocusHeroCard(),
                const SizedBox(height: 10),
                _ReactiveSessionStateCard(store: _sessionStore),
                const SizedBox(height: 22),
                Text(
                  'Get started',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                _ReactiveTaskActionCard(store: _taskStore),
                const SizedBox(height: 10),
                _ReactiveAppsActionCard(store: _appsStore),
                const SizedBox(height: 10),
                _ReactiveSessionActionCard(store: _sessionStore),
                const SizedBox(height: 10),
                _ReactiveDailyGoalCard(store: _taskStore),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'Quiet mind, deliberate work.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactiveSessionStateCard extends StatelessWidget {
  const _ReactiveSessionStateCard({required this.store});

  final FocusSessionStore store;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) => _SessionStateCard(session: store.activeSession),
    );
  }
}

class _ReactiveTaskActionCard extends StatelessWidget {
  const _ReactiveTaskActionCard({required this.store});

  final TaskStore store;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final pendingCount = store.pendingCount;
        final totalCount = store.tasks.length;
        return _DashboardActionCard(
          icon: Icons.check_circle_outline,
          title: 'Create your task list',
          badge: pendingCount == 0 ? 'All complete' : '$pendingCount pending',
          subtitle: totalCount == 0
              ? 'Tasks become the conditions for ending a focus lock.'
              : '$totalCount task${totalCount == 1 ? '' : 's'} in your focus list.',
          onTap: () => context.goNamed('tasks'),
        );
      },
    );
  }
}

class _ReactiveAppsActionCard extends StatelessWidget {
  const _ReactiveAppsActionCard({required this.store});

  final ProtectedAppsStore store;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final selectedCount = store.selectedCount;
        return _DashboardActionCard(
          icon: Icons.phone_android_outlined,
          title: 'Apps to lock',
          badge: '$selectedCount selected',
          subtitle: selectedCount == 0
              ? 'Choose which distracting apps are unavailable during focus.'
              : '$selectedCount app${selectedCount == 1 ? '' : 's'} selected for focus locks.',
          onTap: () => context.goNamed('apps-to-lock'),
        );
      },
    );
  }
}

class _ReactiveSessionActionCard extends StatelessWidget {
  const _ReactiveSessionActionCard({required this.store});

  final FocusSessionStore store;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final session = store.activeSession;
        return _DashboardActionCard(
          icon: Icons.lock_outline,
          title: 'Active focus session',
          subtitle: session == null
              ? 'No focus session is active right now.'
              : '${session.taskTitle} is locking ${session.packageIds.length} app${session.packageIds.length == 1 ? '' : 's'}.',
          onTap: () => context.goNamed('focus-session'),
        );
      },
    );
  }
}

class _ReactiveDailyGoalCard extends StatelessWidget {
  const _ReactiveDailyGoalCard({required this.store});

  final TaskStore store;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final totalCount = store.tasks.length;
        return _DailyGoalCard(
          completedCount: totalCount - store.pendingCount,
          totalCount: totalCount,
        );
      },
    );
  }
}

class _FocusHeroCard extends StatelessWidget {
  const _FocusHeroCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 64, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.lock_clock_outlined,
                    size: 30,
                    color: colors.onPrimaryContainer,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Protect your focus',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Finish the tasks you choose before your selected apps become available again.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onPrimaryContainer,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: -10,
              bottom: -18,
              child: Icon(
                Icons.hourglass_empty,
                size: 132,
                color: colors.onPrimaryContainer.withValues(alpha: .10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionStateCard extends StatelessWidget {
  const _SessionStateCard({required this.session});

  final LockSessionModel? session;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: <Widget>[
          Icon(Icons.hourglass_empty, size: 20, color: colors.outline),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'SESSION STATE',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(letterSpacing: .8),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              session == null
                  ? '◷  Standby • Idle'
                  : '🔒  ${_stateLabel(session!.state)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

String _stateLabel(LockSessionState state) => switch (state) {
  LockSessionState.scheduled => 'Scheduled',
  LockSessionState.active => 'Active',
  LockSessionState.unlockPending => 'Unlock pending',
  LockSessionState.completed => 'Completed',
  LockSessionState.cancelled => 'Cancelled',
};

class _DashboardActionCard extends StatelessWidget {
  const _DashboardActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 19, color: colors.outline),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badge!,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: colors.onPrimaryContainer),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 20, color: colors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard({
    required this.completedCount,
    required this.totalCount,
  });

  final int completedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            SizedBox.square(
              dimension: 52,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  CircularProgressIndicator(
                    value: totalCount == 0 ? 0 : completedCount / totalCount,
                    strokeWidth: 6,
                    backgroundColor: colors.surfaceContainerHighest,
                  ),
                  Text(
                    '${totalCount == 0 ? 0 : (completedCount * 100 ~/ totalCount)}%',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Task progress',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '$completedCount of $totalCount tasks completed',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.goNamed('tasks'),
              child: const Text('Details'),
            ),
          ],
        ),
      ),
    );
  }
}
