import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:project_app_lock/data/study_content_model.dart';
import 'package:project_app_lock/dependency/dependency_manager.dart';
import 'package:project_app_lock/features/tasks/task_editor_store.dart';

class TaskEditorScreen extends StatefulWidget {
  const TaskEditorScreen({super.key, this.taskId});

  final String? taskId;

  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  late final TaskEditorStore _store;
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _durationController;

  @override
  void initState() {
    super.initState();
    _store = sl<TaskEditorStore>();
    _titleController = TextEditingController();
    _notesController = TextEditingController();
    _durationController = TextEditingController(text: '25');
    final id = widget.taskId;
    if (id != null) {
      _store.load(id).then((_) {
        if (!mounted) return;
        _titleController.text = _store.title;
        _notesController.text = _store.sourceNotes;
        _durationController.text = '${_store.durationMinutes}';
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _store
      ..setTitle(_titleController.text)
      ..setSourceNotes(_notesController.text)
      ..setDuration(int.tryParse(_durationController.text) ?? 0);
    if (await _store.save() && mounted) context.goNamed('tasks');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taskId == null ? 'Create task' : 'Edit task'),
        leading: IconButton(
          tooltip: 'Back to tasks',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed('tasks'),
        ),
      ),
      body: Observer(
        builder: (context) {
          if (_store.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: <Widget>[
                TextField(
                  controller: _titleController,
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Task title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration in minutes (1–1440)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Study format',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<StudyFormat>(
                  segments: const <ButtonSegment<StudyFormat>>[
                    ButtonSegment(
                      value: StudyFormat.quiz,
                      label: Text('Quiz'),
                      icon: Icon(Icons.quiz_outlined),
                    ),
                    ButtonSegment(
                      value: StudyFormat.flashcards,
                      label: Text('Flashcards'),
                      icon: Icon(Icons.style_outlined),
                    ),
                  ],
                  selected: <StudyFormat>{_store.format},
                  onSelectionChanged: (value) => _store.setFormat(value.first),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Source notes',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Study items',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_store.items.isEmpty)
                  Text(
                    'Add a prompt and answer to begin.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                for (var index = 0; index < _store.items.length; index++)
                  _StudyItemEditor(
                    key: ValueKey<String>(_store.items[index].id),
                    item: _store.items[index],
                    index: index,
                    canMoveUp: index > 0,
                    canMoveDown: index < _store.items.length - 1,
                    onPromptChanged: (value) => _store.updateItem(
                      _store.items[index].id,
                      prompt: value,
                    ),
                    onAnswerChanged: (value) => _store.updateItem(
                      _store.items[index].id,
                      answer: value,
                    ),
                    onMoveUp: () => _store.moveItem(index, index - 1),
                    onMoveDown: () => _store.moveItem(index, index + 1),
                    onDelete: () => _store.removeItem(_store.items[index].id),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _store.addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add item'),
                ),
                if (_store.errorMessage != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    _store.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _store.isSaving ? null : _save,
                  child: _store.isSaving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save task'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StudyItemEditor extends StatelessWidget {
  const _StudyItemEditor({
    super.key,
    required this.item,
    required this.index,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onPromptChanged,
    required this.onAnswerChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  final StudyItemModel item;
  final int index;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<String> onPromptChanged;
  final ValueChanged<String> onAnswerChanged;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Item ${index + 1}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: 'Move item up',
                onPressed: canMoveUp ? onMoveUp : null,
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'Move item down',
                onPressed: canMoveDown ? onMoveDown : null,
                icon: const Icon(Icons.arrow_downward),
              ),
              IconButton(
                tooltip: 'Delete item',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          TextFormField(
            initialValue: item.prompt,
            onChanged: onPromptChanged,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Prompt',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: item.answer,
            onChanged: onAnswerChanged,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Answer',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
  );
}
