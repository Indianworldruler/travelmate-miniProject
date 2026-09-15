import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'models.dart';
import 'storage_service.dart';
import 'sync_service.dart';

class ExpenseTrackingScreen extends StatefulWidget {
  final String tripId;

  const ExpenseTrackingScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<ExpenseTrackingScreen> createState() => _ExpenseTrackingScreenState();
}

class _ExpenseTrackingScreenState extends State<ExpenseTrackingScreen> {
  final StorageService _storage = StorageService.instance;
  final SyncService _sync = SyncService.instance;

  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Expense>>(
      stream: _storage.watchExpenses(widget.tripId),
      builder: (context, snapshot) {
        final expenses = [...(snapshot.data ?? const <Expense>[])];

        expenses.sort((a, b) => b.date.compareTo(a.date));

        final categories = <String>{
          ...expenses.map((expense) => expense.category),
        }..removeWhere((category) => category.trim().isEmpty);

        final filtered = _filter == 'All'
            ? expenses
            : expenses
                .where((expense) => expense.category == _filter)
                .toList();

        final total = expenses.fold<double>(
          0,
          (sum, expense) => sum + expense.amount,
        );

        final filteredTotal = filtered.fold<double>(
          0,
          (sum, expense) => sum + expense.amount,
        );

        final currency =
            expenses.isNotEmpty ? expenses.first.currency : 'INR';

        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: AppBar(
            title: const Text('Expense tracking'),
            actions: [
              IconButton(
                tooltip: 'Add expense',
                onPressed: () => _showExpenseDialog(),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  wide ? 28 : 20,
                  18,
                  wide ? 28 : 20,
                  90,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryCard(
                      total: total,
                      count: expenses.length,
                      currency: currency,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text(
                          'Trip expenses',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        if (filtered.isNotEmpty)
                          Text(
                            '${_money(filteredTotal, currency)} shown',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (categories.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'All',
                              selected: _filter == 'All',
                              onTap: () {
                                setState(() => _filter = 'All');
                              },
                            ),
                            for (final category in categories)
                              _FilterChip(
                                label: category,
                                selected: _filter == category,
                                onTap: () {
                                  setState(() => _filter = category);
                                },
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),
                    if (filtered.isEmpty)
                      _EmptyExpenses(
                        onAdd: _showExpenseDialog,
                      )
                    else
                      _ExpenseList(
                        expenses: filtered,
                        onEdit: _showExpenseDialog,
                        onDelete: _deleteExpense,
                      ),
                  ],
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showExpenseDialog(),
            backgroundColor: AppTheme.coral,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add expense'),
          ),
        );
      },
    );
  }

  Future<void> _deleteExpense(Expense expense) async {
    await _sync.deleteModel(
      entity: 'expenses',
      tripId: expense.tripId,
      entityId: expense.id,
      localDelete: () => _storage.deleteExpense(expense.id),
    );
  }

  Future<void> _showExpenseDialog([Expense? existing]) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _ExpenseDialog(
          existing: existing,
          tripId: widget.tripId,
          storage: _storage,
          sync: _sync,
        );
      },
    );
  }

  static String _money(double value, String currency) {
    return '$currency ${value.toStringAsFixed(2)}';
  }
}

class _ExpenseDialog extends StatefulWidget {
  final Expense? existing;
  final String tripId;
  final StorageService storage;
  final SyncService sync;

  const _ExpenseDialog({
    required this.existing,
    required this.tripId,
    required this.storage,
    required this.sync,
  });

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _currencyController;
  late final TextEditingController _categoryController;
  late final TextEditingController _paidByController;
  late final TextEditingController _noteController;

  late DateTime _date;

  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _titleController = TextEditingController(
      text: existing?.title ?? '',
    );

    _amountController = TextEditingController(
      text: existing == null
          ? ''
          : existing.amount.toStringAsFixed(2),
    );

    _currencyController = TextEditingController(
      text: existing?.currency ?? 'INR',
    );

    _categoryController = TextEditingController(
      text: existing?.category ?? 'Food',
    );

    _paidByController = TextEditingController(
      text: existing?.paidBy ?? '',
    );

    _noteController = TextEditingController(
      text: existing?.note ?? '',
    );

    _date = existing?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _currencyController.dispose();
    _categoryController.dispose();
    _paidByController.dispose();
    _noteController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEditing ? 'Edit expense' : 'Add expense',
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Expense title',
                  hintText: 'e.g. Dinner at Thalassa',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _currencyController,
                      textCapitalization:
                          TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _categoryController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _paidByController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Paid by',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.calendar_today_rounded,
                ),
                title: Text(_formatDate(_date)),
                subtitle: const Text('Expense date'),
                trailing: TextButton(
                  onPressed: _saving ? null : _changeDate,
                  child: const Text('Change'),
                ),
              ),
              TextField(
                controller: _noteController,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  alignLabelWithHint: true,
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
                  _isEditing ? 'Save changes' : 'Add expense',
                ),
        ),
      ],
    );
  }

  Future<void> _changeDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _date,
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _date = picked;
    });
  }

  Future<void> _save() async {
    final titleValue = _titleController.text.trim();

    final amountValue = double.tryParse(
      _amountController.text.trim().replaceAll(',', ''),
    );

    if (titleValue.isEmpty || amountValue == null) {
      _showValidationMessage(
        'Enter a valid expense title and amount.',
      );
      return;
    }

    if (_saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    final expense = Expense(
      id: widget.existing?.id ?? widget.storage.newId(),
      tripId: widget.tripId,
      title: titleValue,
      amount: amountValue,
      currency: _currencyController.text.trim().isEmpty
          ? 'INR'
          : _currencyController.text.trim().toUpperCase(),
      category: _categoryController.text.trim().isEmpty
          ? 'Other'
          : _categoryController.text.trim(),
      paidBy: _paidByController.text.trim(),
      date: _date,
      note: _noteController.text.trim(),
      updatedAt: DateTime.now(),
    );

    try {
      await widget.sync.saveModel(
        model: expense,
        entity: 'expenses',
        localSave: () => widget.storage.saveExpense(expense),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _showValidationMessage(
        'Could not save the expense. Please try again.',
      );
    }
  }

  void _showValidationMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

class _SummaryCard extends StatelessWidget {
  final double total;
  final int count;
  final String currency;

  const _SummaryCard({
    required this.total,
    required this.count,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppTheme.navy900,
            AppTheme.navy700,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 18,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trip spending',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 6),
            ],
          ),
          Text(
            '$currency ${total.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '$count ${count == 1 ? 'expense' : 'expenses'}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseList extends StatelessWidget {
  final List<Expense> expenses;
  final Future<void> Function(Expense) onEdit;
  final Future<void> Function(Expense) onDelete;

  const _ExpenseList({
    required this.expenses,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final expense in expenses)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                leading: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _categoryColor(expense.category)
                        .withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _categoryIcon(expense.category),
                    color: _categoryColor(expense.category),
                  ),
                ),
                title: Text(
                  expense.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        expense.category,
                        style: const TextStyle(
                          color: AppTheme.teal,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      if (expense.paidBy.isNotEmpty)
                        Text(
                          'Paid by ${expense.paidBy}',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      Text(
                        _formatDate(expense.date),
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit(expense);
                    }

                    if (value == 'delete') {
                      onDelete(expense);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  static Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'dining':
        return AppTheme.coral;
      case 'transport':
        return AppTheme.teal;
      case 'hotel':
      case 'accommodation':
        return AppTheme.navy700;
      case 'shopping':
        return AppTheme.warning;
      default:
        return AppTheme.navy800;
    }
  }

  static IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'dining':
        return Icons.restaurant_rounded;
      case 'transport':
        return Icons.directions_car_rounded;
      case 'hotel':
      case 'accommodation':
        return Icons.hotel_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppTheme.teal100,
        side: BorderSide(
          color: selected
              ? AppTheme.teal
              : AppTheme.border,
        ),
        labelStyle: TextStyle(
          color: selected
              ? AppTheme.teal
              : AppTheme.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyExpenses extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyExpenses({
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: AppTheme.border,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            size: 46,
            color: AppTheme.teal,
          ),
          const SizedBox(height: 12),
          const Text(
            'No expenses yet',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add your first expense to start tracking trip spending.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add expense'),
          ),
        ],
      ),
    );
  }
}