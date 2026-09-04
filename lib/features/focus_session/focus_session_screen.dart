import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:project_app_lock/dependency/dependency_manager.dart';
import 'package:project_app_lock/features/focus_session/focus_session_store.dart';
import 'package:project_app_lock/shared/widgets/app_scaffold.dart';

class FocusSessionScreen extends StatefulWidget {
  const FocusSessionScreen({super.key});

  @override
  State<FocusSessionScreen> createState() => _FocusSessionScreenState();
}

class _FocusSessionScreenState extends State<FocusSessionScreen> {
  late final FocusSessionStore _store;

  @override
  void initState() {
    super.initState();
    _store = sl<FocusSessionStore>()..initialize();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  Future<void> _complete() async {
    final finished = await _store.completeActiveTask();
    if (!mounted) return;
    if (finished) context.goNamed('tasks');
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Active Session',
      onBackPressed: () => context.goNamed('home'),
      body: Observer(
        builder: (context) {
          final session = _store.activeSession;
          if (session == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.timer_off_outlined, size: 48),
                    const SizedBox(height: 16),
                    const Text('There is no active focus session.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.goNamed('tasks'),
                      child: const Text('View tasks'),
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: <Widget>[
                    _SessionTimer(
                      remaining: _store.remaining,
                      total: session.endsAt.difference(session.startedAt),
                      formattedRemaining: _formatDuration(_store.remaining),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'GOAL TO UNLOCK',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.taskTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Finish: ${session.taskTitle}',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${session.packageIds.length} apps locked',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (_store.errorMessage != null) ...<Widget>[
                      const SizedBox(height: 16),
                      Text(
                        _store.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 32),
                    if (_store.needsUnlockRetry)
                      FilledButton.icon(
                        onPressed: _store.isBusy ? null : _store.retryUnlock,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry unlock'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: _store.isBusy ? null : _complete,
                        icon: const Icon(Icons.task_alt),
                        label: const Text('Complete task and unlock'),
                      ),
                    const SizedBox(height: 32),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Distraction Shield',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: <Widget>[
                          for (final packageId in session.packageIds)
                            ListTile(
                              leading: const Icon(Icons.lock_outline),
                              title: Text(packageId),
                              subtitle: const Text(
                                'Locked until this focus session ends',
                              ),
                              trailing: const Icon(Icons.lock, size: 16),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SessionTimer extends StatelessWidget {
  const _SessionTimer({
    required this.remaining,
    required this.total,
    required this.formattedRemaining,
  });

  final Duration remaining;
  final Duration total;
  final String formattedRemaining;

  @override
  Widget build(BuildContext context) {
    final totalMilliseconds = total.inMilliseconds;
    final progress = totalMilliseconds <= 0
        ? 0.0
        : (remaining.inMilliseconds / totalMilliseconds).clamp(0.0, 1.0);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned.fill(
              child: Semantics(
                label: 'Time remaining',
                value: formattedRemaining,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formattedRemaining,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                  Text(
                    'REMAINING',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
