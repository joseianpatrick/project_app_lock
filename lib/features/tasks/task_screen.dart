import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:project_app_lock/data/study_content_model.dart';
import 'package:project_app_lock/data/task_model.dart';
import 'package:project_app_lock/dependency/dependency_manager.dart';
import 'package:project_app_lock/features/focus_session/focus_session_store.dart';
import 'package:project_app_lock/features/tasks/task_store.dart';
import 'package:project_app_lock/shared/widgets/app_scaffold.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});
  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  late final TaskStore _store;
  late final FocusSessionStore _sessionStore;
  @override
  void initState() {
    super.initState();
    _store = sl<TaskStore>()..initialize();
    _sessionStore = sl<FocusSessionStore>()..initialize();
  }

  Future<void> _startFocus(TaskModel task) async {
    final validation = await _sessionStore.validateStart(task);
    if (!mounted) return;
    if (validation != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validation)));
      return;
    }
    final selectedAppCount = await _sessionStore.getSelectedAppCount();
    if (!mounted) return;
    final settings = await _sessionStore.settingsRepository.load();
    if (!mounted) return;
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start focus?'),
        content: Text(
          '${task.title}\n\nYour selected apps will be locked for ${task.durationMinutes} minutes.\n\n'
          'Focus behavior for this session:\n'
          '• Lock navigation to task: ${settings.lockToTaskScreen ? 'On' : 'Off'}\n'
          '• Allow other apps: ${settings.allowOtherApps ? 'On' : 'Off'}\n'
          '• Enable Back button: ${settings.backButtonEnabled ? 'On' : 'Off'}\n\n'
          '$selectedAppCount selected app${selectedAppCount == 1 ? '' : 's'} will be locked.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start focus'),
          ),
        ],
      ),
    );
    if (confirmed == true && await _sessionStore.start(task) && mounted) {
      context.goNamed('focus-session');
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Tasks',
    onBackPressed: () => context.goNamed('home'),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => context.goNamed('task-create'),
      icon: const Icon(Icons.add),
      label: const Text('Add task'),
    ),
    body: Observer(
      builder: (context) {
        if (_store.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_store.isEmpty) {
          return const _TaskMessage(
            icon: Icons.quiz_outlined,
            message: 'No study tasks yet. Add a quiz or flashcard task.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: _store.tasks.length,
          itemBuilder: (context, index) {
            final task = _store.tasks[index];
            return _TaskCard(
              task: task,
              onEdit: () => context.goNamed(
                'task-edit',
                pathParameters: <String, String>{'taskId': task.id},
              ),
              onDelete: () => _store.deleteTask(task.id),
              onStart: task.studyContent == null || task.isCompleted
                  ? null
                  : () => _startFocus(task),
            );
          },
        );
      },
    ),
  );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onEdit,
    required this.onDelete,
    this.onStart,
  });
  final TaskModel task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onStart;
  @override
  Widget build(BuildContext context) {
    final content = task.studyContent;
    final status = task.isCompleted
        ? 'Completed'
        : content == null
        ? 'Study content required'
        : 'Ready to study';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Task options',
                  onSelected: (value) =>
                      value == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => const <PopupMenuEntry<String>>[
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              status,
              style: TextStyle(
                color: content == null
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content == null
                  ? '${task.durationMinutes} minutes'
                  : '${content.format == StudyFormat.quiz ? 'Quiz' : 'Flashcards'} · ${content.items.length} ${content.items.length == 1 ? 'item' : 'items'} · ${task.durationMinutes} minutes',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  onPressed: onEdit,
                  child: Text(content == null ? 'Add content' : 'Edit'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onStart,
                  icon: const Icon(Icons.lock_clock_outlined),
                  label: const Text('Start focus'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskMessage extends StatelessWidget {
  const _TaskMessage({required this.icon, required this.message});
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 48),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
