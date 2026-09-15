import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'models.dart';
import 'storage_service.dart';
import 'sync_service.dart';

class TravelTodoScreen extends StatefulWidget {
  final String tripId;

  const TravelTodoScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<TravelTodoScreen> createState() => _TravelTodoScreenState();
}

class _TravelTodoScreenState extends State<TravelTodoScreen> {
  final StorageService _storage = StorageService.instance;
  final SyncService _sync = SyncService.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TodoItem>>(
      stream: _storage.watchTodos(widget.tripId),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <TodoItem>[];

        return StreamBuilder<SyncStatus>(
          stream: _sync.statusStream,
          initialData: _sync.status,
          builder: (context, statusSnapshot) {
            final online = statusSnapshot.data?.online ?? false;

            final todo = items
                .where((item) => item.status == 'todo')
                .toList();

            final progress = items
                .where((item) => item.status == 'in_progress')
                .toList();

            final completed = items
                .where((item) => item.status == 'completed')
                .toList();

            return Scaffold(
              backgroundColor: AppTheme.bg,
              appBar: AppBar(
                title: const Text('Travel to-do list'),
                actions: [
                  if (!online)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.cloud_off_rounded,
                        color: AppTheme.coral,
                      ),
                    ),
                  IconButton(
                    tooltip: 'Add task',
                    onPressed: () => _showTodoDialog(),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;

                  final columns = <List<TodoItem>>[
                    todo,
                    progress,
                    completed,
                  ];

                  final names = <String>[
                    'To Do',
                    'In Progress',
                    'Completed',
                  ];

                  final colors = <Color>[
                    AppTheme.coral,
                    AppTheme.warning,
                    AppTheme.teal,
                  ];

                  if (!wide) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        32,
                      ),
                      children: [
                        _IntroCard(online: online),
                        const SizedBox(height: 20),
                        for (var i = 0; i < columns.length; i++) ...[
                          _ColumnSection(
                            title: names[i],
                            color: colors[i],
                            items: columns[i],
                            onToggle: _toggleStatus,
                            onEdit: _showTodoDialog,
                            onDelete: _delete,
                          ),
                          if (i != columns.length - 1)
                            const SizedBox(height: 22),
                        ],
                      ],
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      28,
                      20,
                      28,
                      40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _IntroCard(online: online),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < columns.length; i++)
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: i == columns.length - 1 ? 0 : 16,
                                  ),
                                  child: _ColumnSection(
                                    title: names[i],
                                    color: colors[i],
                                    items: columns[i],
                                    onToggle: _toggleStatus,
                                    onEdit: _showTodoDialog,
                                    onDelete: _delete,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _showTodoDialog(),
                backgroundColor: AppTheme.coral,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add task'),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleStatus(TodoItem item) async {
    final next = switch (item.status) {
      'todo' => 'in_progress',
      'in_progress' => 'completed',
      _ => 'todo',
    };

    final updated = TodoItem(
      id: item.id,
      tripId: item.tripId,
      title: item.title,
      description: item.description,
      status: next,
      priority: item.priority,
      dueDate: item.dueDate,
      updatedAt: DateTime.now(),
    );

    await _sync.saveModel(
      model: updated,
      entity: 'todos',
      localSave: () => _storage.saveTodo(updated),
    );
  }

  Future<void> _delete(TodoItem item) async {
    await _sync.deleteModel(
      entity: 'todos',
      tripId: item.tripId,
      entityId: item.id,
      localDelete: () => _storage.deleteTodo(item.id),
    );
  }

  Future<void> _showTodoDialog([TodoItem? existing]) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _TodoDialog(
          existing: existing,
          tripId: widget.tripId,
          storage: _storage,
          sync: _sync,
        );
      },
    );
  }
}

// ============================================================
// TODO DIALOG
// ============================================================

class _TodoDialog extends StatefulWidget {
  final TodoItem? existing;
  final String tripId;
  final StorageService storage;
  final SyncService sync;

  const _TodoDialog({
    required this.existing,
    required this.tripId,
    required this.storage,
    required this.sync,
  });

  @override
  State<_TodoDialog> createState() => _TodoDialogState();
}

class _TodoDialogState extends State<_TodoDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  late String _priority;
  DateTime? _dueDate;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );

    _descriptionController = TextEditingController(
      text: widget.existing?.description ?? '',
    );

    _priority = widget.existing?.priority ?? 'medium';
    _dueDate = widget.existing?.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _dueDate ?? DateTime.now(),
    );

    if (!mounted) return;

    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    final title = _titleController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a task title.'),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final item = TodoItem(
        id: widget.existing?.id ?? widget.storage.newId(),
        tripId: widget.tripId,
        title: title,
        description: _descriptionController.text.trim(),
        status: widget.existing?.status ?? 'todo',
        priority: _priority,
        dueDate: _dueDate,
        updatedAt: DateTime.now(),
      );

      await widget.sync.saveModel(
        model: item,
        entity: 'todos',
        localSave: () => widget.storage.saveTodo(item),
      );

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save task: $error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEditing ? 'Edit task' : 'Add task',
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Task title',
                  hintText: 'e.g. Buy travel insurance',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Add some additional details',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'high',
                    child: Text('High'),
                  ),
                  DropdownMenuItem(
                    value: 'medium',
                    child: Text('Medium'),
                  ),
                  DropdownMenuItem(
                    value: 'low',
                    child: Text('Low'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value == null) return;

                        setState(() {
                          _priority = value;
                        });
                      },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.calendar_today_rounded,
                ),
                title: Text(
                  _dueDate == null
                      ? 'No due date'
                      : 'Due ${_dateLabel(_dueDate!)}',
                ),
                trailing: TextButton(
                  onPressed: _saving ? null : _chooseDate,
                  child: const Text('Choose'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  _isEditing ? 'Save changes' : 'Add task',
                ),
        ),
      ],
    );
  }

  String _dateLabel(DateTime date) {
    return '${date.day} ${_month(date.month)}';
  }

  String _month(int value) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return months[value];
  }
}

// ============================================================
// INTRO CARD
// ============================================================

class _IntroCard extends StatelessWidget {
  final bool online;

  const _IntroCard({
    required this.online,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppTheme.navy900,
            AppTheme.navy700,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              online
                  ? Icons.checklist_rounded
                  : Icons.cloud_off_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Before your trip',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Keep preparation tasks organised and move them across stages.',
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.35,
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

// ============================================================
// COLUMN SECTION
// ============================================================

class _ColumnSection extends StatelessWidget {
  final String title;
  final Color color;
  final List<TodoItem> items;
  final Future<void> Function(TodoItem) onToggle;
  final Future<void> Function(TodoItem) onEdit;
  final Future<void> Function(TodoItem) onDelete;

  const _ColumnSection({
    required this.title,
    required this.color,
    required this.items,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: AppTheme.bgAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${items.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: AppTheme.border,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'No tasks here yet.',
              style: TextStyle(
                color: AppTheme.textMuted,
              ),
            ),
          )
        else
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TodoCard(
                item: item,
                onToggle: () => onToggle(item),
                onEdit: () => onEdit(item),
                onDelete: () => onDelete(item),
              ),
            ),
      ],
    );
  }
}

// ============================================================
// TODO CARD
// ============================================================

class _TodoCard extends StatelessWidget {
  final TodoItem item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TodoCard({
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final done = item.status == 'completed';

    final priorityColor = switch (item.priority) {
      'high' => AppTheme.coral,
      'medium' => AppTheme.warning,
      _ => AppTheme.textMuted,
    };

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 180,
                  ),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: done
                        ? AppTheme.teal
                        : Colors.white,
                    border: Border.all(
                      color: done
                          ? AppTheme.teal
                          : AppTheme.border,
                      width: 1.5,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: done
                      ? const Icon(
                          Icons.check,
                          size: 15,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        decoration: done
                            ? TextDecoration.lineThrough
                            : null,
                        color: done
                            ? AppTheme.textMuted
                            : AppTheme.textPrimary,
                      ),
                    ),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Chip(
                          text: _capitalise(item.priority),
                          color: priorityColor,
                        ),
                        if (item.dueDate != null)
                          _Chip(
                            text: _shortDate(
                              item.dueDate!,
                            ),
                            color: AppTheme.navy700,
                            icon:
                                Icons.calendar_today_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  }

                  if (value == 'delete') {
                    onDelete();
                  }

                  if (value == 'toggle') {
                    onToggle();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      done
                          ? 'Move to To Do'
                          : 'Move to next stage',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _capitalise(String value) {
    if (value.isEmpty) return value;

    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  static String _shortDate(DateTime date) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month]}';
  }
}

// ============================================================
// CHIP
// ============================================================

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const _Chip({
    required this.text,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 11,
              color: color,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}