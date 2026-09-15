import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'models.dart';
import 'storage_service.dart';
import 'sync_service.dart';

class TravelNotesScreen extends StatefulWidget {
  final String tripId;

  const TravelNotesScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<TravelNotesScreen> createState() => _TravelNotesScreenState();
}

class _TravelNotesScreenState extends State<TravelNotesScreen> {
  final StorageService _storage = StorageService.instance;
  final SyncService _sync = SyncService.instance;

  final TextEditingController _searchController =
      TextEditingController();

  String _query = '';
  String? _selectedId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TravelNote>>(
      stream: _storage.watchNotes(widget.tripId),
      builder: (context, snapshot) {
        final allNotes =
            snapshot.data ?? const <TravelNote>[];

        final filtered = allNotes.where((note) {
          final q = _query.trim().toLowerCase();

          if (q.isEmpty) {
            return true;
          }

          return note.title.toLowerCase().contains(q) ||
              note.content.toLowerCase().contains(q) ||
              note.category.toLowerCase().contains(q);
        }).toList()
          ..sort(
            (a, b) =>
                b.updatedAt.compareTo(a.updatedAt),
          );

        TravelNote? selected;

        if (_selectedId != null) {
          for (final note in filtered) {
            if (note.id == _selectedId) {
              selected = note;
              break;
            }
          }
        }

        selected ??=
            filtered.isNotEmpty ? filtered.first : null;

        if (selected != null &&
            _selectedId != selected.id) {
          final selectedId = selected.id;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            if (_selectedId != selectedId) {
              setState(() {
                _selectedId = selectedId;
              });
            }
          });
        }

        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: AppBar(
            title: const Text('Travel notes'),
            actions: [
              IconButton(
                tooltip: 'Add note',
                onPressed: () => _showNoteDialog(),
                icon: const Icon(
                  Icons.add_rounded,
                ),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 850;

              if (!wide) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    32,
                  ),
                  children: [
                    _SearchBox(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _query = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    if (filtered.isEmpty)
                      _EmptyNotes(
                        onAdd: _showNoteDialog,
                      )
                    else ...[
                      _NotesList(
                        notes: filtered,
                        selectedId: selected?.id,
                        onSelect: (note) {
                          setState(() {
                            _selectedId = note.id;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      if (selected != null)
                        _NoteEditor(
                          note: selected,
                          onEdit: () =>
                              _showNoteDialog(selected),
                          onDelete: () =>
                              _delete(selected!),
                        ),
                    ],
                  ],
                );
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  28,
                  20,
                  28,
                  32,
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 310,
                      child: Column(
                        children: [
                          _SearchBox(
                            controller:
                                _searchController,
                            onChanged: (value) {
                              setState(() {
                                _query = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          if (filtered.isEmpty)
                            _EmptyNotes(
                              onAdd: _showNoteDialog,
                            )
                          else
                            _NotesList(
                              notes: filtered,
                              selectedId: selected?.id,
                              onSelect: (note) {
                                setState(() {
                                  _selectedId = note.id;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: selected == null
                          ? _EmptyNotes(
                              onAdd: _showNoteDialog,
                            )
                          : _NoteEditor(
                              note: selected,
                              onEdit: () =>
                                  _showNoteDialog(selected),
                              onDelete: () =>
                                  _delete(selected!),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
          floatingActionButton:
              FloatingActionButton.extended(
            onPressed: () => _showNoteDialog(),
            backgroundColor: AppTheme.coral,
            foregroundColor: Colors.white,
            icon: const Icon(
              Icons.add_rounded,
            ),
            label: const Text('Add note'),
          ),
        );
      },
    );
  }

  Future<void> _delete(
    TravelNote note,
  ) async {
    await _sync.deleteModel(
      entity: 'notes',
      tripId: note.tripId,
      entityId: note.id,
      localDelete: () =>
          _storage.deleteNote(note.id),
    );

    if (!mounted) return;

    setState(() {
      _selectedId = null;
    });
  }

  Future<void> _showNoteDialog([
    TravelNote? existing,
  ]) async {
    final result =
        await showDialog<_TravelNoteDialogResult>(
      context: context,
      builder: (dialogContext) {
        return _TravelNoteDialog(
          existing: existing,
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    final note = TravelNote(
      id: existing?.id ?? _storage.newId(),
      tripId: widget.tripId,
      title: result.title,
      content: result.content,
      category: result.category,
      updatedAt: DateTime.now(),
    );

    await _sync.saveModel(
      model: note,
      entity: 'notes',
      localSave: () =>
          _storage.saveNote(note),
    );

    if (!mounted) return;

    setState(() {
      _selectedId = note.id;
    });
  }
}

class _TravelNoteDialog extends StatefulWidget {
  final TravelNote? existing;

  const _TravelNoteDialog({
    this.existing,
  });

  @override
  State<_TravelNoteDialog> createState() =>
      _TravelNoteDialogState();
}

class _TravelNoteDialogState
    extends State<_TravelNoteDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _categoryController;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );

    _contentController = TextEditingController(
      text: widget.existing?.content ?? '',
    );

    _categoryController = TextEditingController(
      text: widget.existing?.category ?? 'General',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _categoryController.dispose();

    super.dispose();
  }

  void _submit() {
    final title =
        _titleController.text.trim();

    final content =
        _contentController.text.trim();

    final category =
        _categoryController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      _TravelNoteDialogResult(
        title: title,
        content: content,
        category: category.isEmpty
            ? 'General'
            : category,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;

    return AlertDialog(
      title: Text(
        editing ? 'Edit note' : 'Add note',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                textInputAction:
                    TextInputAction.next,
                decoration:
                    const InputDecoration(
                  labelText: 'Note title',
                  hintText:
                      'e.g. Hotel Check-in',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _categoryController,
                textInputAction:
                    TextInputAction.next,
                decoration:
                    const InputDecoration(
                  labelText: 'Category',
                  hintText:
                      'General, Food, Places, Reminder...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentController,
                minLines: 7,
                maxLines: 12,
                decoration:
                    const InputDecoration(
                  labelText: 'Note',
                  hintText:
                      'Write your travel note...',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            editing
                ? 'Save changes'
                : 'Add note',
          ),
        ),
      ],
    );
  }
}

class _TravelNoteDialogResult {
  final String title;
  final String content;
  final String category;

  const _TravelNoteDialogResult({
    required this.title,
    required this.content,
    required this.category,
  });
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBox({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search notes...',
        prefixIcon: const Icon(
          Icons.search_rounded,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(
                  Icons.close_rounded,
                ),
              ),
      ),
    );
  }
}

class _NotesList extends StatelessWidget {
  final List<TravelNote> notes;
  final String? selectedId;
  final ValueChanged<TravelNote> onSelect;

  const _NotesList({
    required this.notes,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.only(
              bottom: 6,
            ),
            child: Material(
              color: note.id == selectedId
                  ? AppTheme.teal100
                  : Colors.white,
              borderRadius:
                  BorderRadius.circular(12),
              child: InkWell(
                onTap: () => onSelect(note),
                borderRadius:
                    BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(12),
                    border: Border.all(
                      color: note.id == selectedId
                          ? AppTheme.teal
                          : AppTheme.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              note.title,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                          ),
                          if (note.category
                              .toLowerCase()
                              .contains('pin'))
                            const Icon(
                              Icons
                                  .push_pin_rounded,
                              size: 15,
                              color:
                                  AppTheme.coral,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        note.content.replaceAll(
                          '\n',
                          ' ',
                        ),
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color:
                              AppTheme.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NoteEditor extends StatelessWidget {
  final TravelNote note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NoteEditor({
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(
          minHeight: 460,
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          AppTheme.coral100,
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Icon(
                          Icons
                              .push_pin_rounded,
                          size: 14,
                          color:
                              AppTheme.coral,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Travel note',
                          style:
                              TextStyle(
                            color:
                                AppTheme.coral,
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: onEdit,
                    icon: const Icon(
                      Icons.edit_outlined,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons
                          .delete_outline_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                note.title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Edited ${_relativeDate(note.updatedAt)}',
                style:
                    const TextStyle(
                  color:
                      AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              if (note.category.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 16,
                  ),
                  child: Text(
                    note.category,
                    style:
                        const TextStyle(
                      color: AppTheme.teal,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              SelectableText(
                note.content,
                style:
                    const TextStyle(
                  color:
                      AppTheme.textSecondary,
                  fontSize: 14.5,
                  height: 1.7,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _relativeDate(
    DateTime date,
  ) {
    final diff =
        DateTime.now().difference(date);

    if (diff.inMinutes < 1) {
      return 'just now';
    }

    if (diff.inHours < 1) {
      return '${diff.inMinutes} min ago';
    }

    if (diff.inDays == 1) {
      return 'yesterday';
    }

    if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    }

    return '${date.day}/${date.month}/${date.year}';
  }
}

class _EmptyNotes extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyNotes({
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        border:
            Border.all(color: AppTheme.border),
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons
                .sticky_note_2_outlined,
            size: 42,
            color: AppTheme.teal,
          ),
          const SizedBox(height: 12),
          const Text(
            'No travel notes yet',
            style: TextStyle(
              fontWeight:
                  FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Capture reminders, recommendations and places to remember.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color:
                  AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(
              Icons.add_rounded,
            ),
            label: const Text(
              'Add first note',
            ),
          ),
        ],
      ),
    );
  }
}