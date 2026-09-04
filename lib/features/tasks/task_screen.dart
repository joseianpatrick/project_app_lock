import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
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

  Future<void> _openTaskDialog([TaskModel? task]) async {
    _store.clearFormError();
    await showAdaptiveDialog<void>(
      context: context,
      builder: (context) => _TaskFormDialog(store: _store, task: task),
    );
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
    final end = DateTime.now().add(Duration(minutes: task.durationMinutes));
    final selectedCount = await _sessionStore.getSelectedAppCount();
    if (!mounted) return;
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start focus?'),
        content: Text(
          '${task.title}\n\n$selectedCount selected ${selectedCount == 1 ? 'app' : 'apps'} will be locked until ${TimeOfDay.fromDateTime(end).format(context)}.',
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
    if (confirmed != true) return;
    final started = await _sessionStore.start(task);
    if (!mounted) return;
    if (started) {
      context.goNamed('focus-session');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_sessionStore.errorMessage ?? 'Could not start focus.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Tasks',
      onBackPressed: () => context.goNamed('home'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openTaskDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
      ),
      body: Observer(
        builder: (context) {
          if (_store.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_store.errorMessage != null && _store.tasks.isEmpty) {
            return _TaskMessage(
              icon: Icons.error_outline,
              message: _store.errorMessage!,
              actionLabel: 'Try again',
              onAction: _store.initialize,
            );
          }
          if (_store.isEmpty) {
            return const _TaskMessage(
              icon: Icons.checklist_outlined,
              message: 'No tasks yet. Add a timed focus task.',
            );
          }
          return CustomScrollView(
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                sliver: SliverList.builder(
                  itemCount: _store.tasks.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'READY TO FOCUS',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                letterSpacing: 1.4,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      );
                    }
                    final task = _store.tasks[index - 1];
                    return _TaskTile(
                      task: task,
                      onEdit: () => _openTaskDialog(task),
                      onStart: task.isCompleted
                          ? null
                          : () => _startFocus(task),
                      onChanged: (value) {
                        if (value == true &&
                            _sessionStore.activeSession?.taskId == task.id) {
                          _sessionStore.completeActiveTask();
                        } else {
                          _store.setCompleted(
                            task,
                            isCompleted: value ?? false,
                          );
                        }
                      },
                      onDelete: () => _store.deleteTask(task.id),
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

class _TaskFormDialog extends StatefulWidget {
  const _TaskFormDialog({required this.store, this.task});

  final TaskStore store;
  final TaskModel? task;

  @override
  State<_TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<_TaskFormDialog> {
  static const List<int> _presets = <int>[15, 25, 45, 60];
  late final TextEditingController _titleController;
  late final TextEditingController _customController;
  late final FocusNode _titleFocus;
  late int _duration;
  bool _custom = false;

  @override
  void initState() {
    super.initState();
    _duration = widget.task?.durationMinutes ?? 25;
    _custom = !_presets.contains(_duration);
    _titleController = TextEditingController(text: widget.task?.title);
    _customController = TextEditingController(
      text: _custom ? '$_duration' : '',
    );
    _titleFocus = FocusNode();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _customController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final duration = _custom
        ? int.tryParse(_customController.text) ?? 0
        : _duration;
    final saved = await widget.store.saveTask(
      id: widget.task?.id,
      title: _titleController.text,
      durationMinutes: duration,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else if (_titleController.text.trim().isEmpty) {
      _titleFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.task == null ? 'Create task' : 'Edit task'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _titleController,
                focusNode: _titleFocus,
                autofocus: true,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Task title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Time period',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final minutes in _presets)
                    ChoiceChip(
                      label: Text('$minutes min'),
                      selected: !_custom && _duration == minutes,
                      onSelected: (_) => setState(() {
                        _custom = false;
                        _duration = minutes;
                      }),
                    ),
                  ChoiceChip(
                    label: const Text('Custom'),
                    selected: _custom,
                    onSelected: (_) => setState(() => _custom = true),
                  ),
                ],
              ),
              if (_custom) ...<Widget>[
                const SizedBox(height: 16),
                TextField(
                  controller: _customController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minutes (1–1440)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              Observer(
                builder: (context) {
                  final error = widget.store.formError;
                  if (error == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        Observer(
          builder: (context) => FilledButton(
            onPressed: widget.store.isSaving ? null : _save,
            child: widget.store.isSaving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.task == null ? 'Create task' : 'Save'),
          ),
        ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onChanged,
    required this.onDelete,
    required this.onEdit,
    this.onStart,
  });

  final TaskModel task;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
        child: Column(
          children: <Widget>[
            CheckboxListTile(
              value: task.isCompleted,
              onChanged: onChanged,
              title: Text(task.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('${task.durationMinutes} minutes'),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.lock_outline,
                        size: 15,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      const Text('Locks selected apps'),
                    ],
                  ),
                ],
              ),
              secondary: PopupMenuButton<String>(
                tooltip: 'Task options',
                onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (_) => const <PopupMenuEntry<String>>[
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
            if (onStart != null)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: onStart,
                  icon: const Icon(Icons.lock_clock_outlined),
                  label: const Text('Start focus'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskMessage extends StatelessWidget {
  const _TaskMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
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
