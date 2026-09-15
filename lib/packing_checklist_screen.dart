import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'models.dart';
import 'storage_service.dart';
import 'sync_service.dart';

class PackingChecklistScreen extends StatefulWidget {
  final String tripId;

  const PackingChecklistScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<PackingChecklistScreen> createState() =>
      _PackingChecklistScreenState();
}

class _PackingChecklistScreenState
    extends State<PackingChecklistScreen> {
  final StorageService _storage = StorageService.instance;
  final SyncService _sync = SyncService.instance;

  List<PackingItem> _items = [];
  String _filter = 'All';
  bool _loading = true;

  final List<String> _categories = const [
    'All',
    'Clothes',
    'Documents',
    'Toiletries',
    'Electronics',
    'Health',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      await _storage.initialise();

      final items = await _storage.getPackingItems(
        widget.tripId,
      );

      if (!mounted) return;

      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _save(PackingItem item) async {
    await _sync.saveModel(
      model: item,
      entity: 'packing_items',
      localSave: () => _storage.savePackingItem(item),
    );
  }

  Future<void> _toggle(PackingItem item) async {
    final updated = PackingItem(
      id: item.id,
      tripId: item.tripId,
      category: item.category,
      name: item.name,
      quantity: item.quantity,
      packed: !item.packed,
      updatedAt: DateTime.now(),
    );

    await _save(updated);
    await _load();
  }

  Future<void> _delete(PackingItem item) async {
    await _sync.deleteModel(
      entity: 'packing_items',
      tripId: widget.tripId,
      entityId: item.id,
      localDelete: () => _storage.deletePackingItem(item.id),
    );

    await _load();
  }

  Future<void> _addItem() async {
    final result = await showDialog<_PackingDialogResult>(
      context: context,
      builder: (_) => const _PackingItemDialog(),
    );

    if (result == null) {
      return;
    }

    if (result.name.trim().isEmpty) {
      return;
    }

    final item = PackingItem(
      id: _storage.newId(),
      tripId: widget.tripId,
      category: result.category,
      name: result.name.trim(),
      quantity: result.quantity,
      packed: false,
      updatedAt: DateTime.now(),
    );

    await _save(item);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'All'
        ? _items
        : _items
            .where((item) => item.category == _filter)
            .toList();

    final packed = _items.where((item) => item.packed).length;

    final progress =
        _items.isEmpty ? 0.0 : packed / _items.length;

    return StreamBuilder<SyncStatus>(
      stream: _sync.statusStream,
      initialData: _sync.status,
      builder: (context, snapshot) {
        final status = snapshot.data ?? _sync.status;

        return Scaffold(
          backgroundColor: TravelMateColors.background,
          appBar: AppBar(
            title: const Text('Packing checklist'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  avatar: Icon(
                    status.online
                        ? Icons.cloud_done
                        : Icons.cloud_off,
                    size: 16,
                    color: status.online
                        ? TravelMateColors.success
                        : TravelMateColors.warning,
                  ),
                  label: Text(
                    status.online ? 'Synced' : 'Offline',
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton:
              FloatingActionButton.extended(
            onPressed: _addItem,
            icon: const Icon(Icons.add),
            label: const Text('Add item'),
          ),
          body: _loading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient:
                              const LinearGradient(
                            colors: [
                              TravelMateColors.navy900,
                              TravelMateColors.navy700,
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color: Colors.white
                                          .withValues(
                                        alpha: .12,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(
                                        999,
                                      ),
                                    ),
                                    child: const Text(
                                      'TRIP PREP',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight:
                                            FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Pack with confidence',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 23,
                                      fontWeight:
                                          FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '$packed of ${_items.length} items packed',
                                    style:
                                        const TextStyle(
                                      color:
                                          Color(0xFFC9D6E0),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 82,
                              height: 82,
                              child: Stack(
                                alignment:
                                    Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: progress,
                                    strokeWidth: 8,
                                    backgroundColor:
                                        Colors.white24,
                                    valueColor:
                                        const AlwaysStoppedAnimation(
                                      TravelMateColors
                                          .teal500,
                                    ),
                                  ),
                                  Text(
                                    '${(progress * 100).round()}%',
                                    style:
                                        const TextStyle(
                                      color: Colors.white,
                                      fontWeight:
                                          FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection:
                              Axis.horizontal,
                          itemCount:
                              _categories.length,
                          separatorBuilder:
                              (_, __) =>
                                  const SizedBox(width: 8),
                          itemBuilder: (_, index) {
                            final category =
                                _categories[index];

                            final selected =
                                _filter == category;

                            return ChoiceChip(
                              label: Text(category),
                              selected: selected,
                              onSelected: (_) {
                                setState(() {
                                  _filter = category;
                                });
                              },
                              selectedColor:
                                  TravelMateColors.navy800,
                              labelStyle: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : TravelMateColors
                                        .textPrimary,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (filtered.isEmpty)
                        Card(
                          child: Padding(
                            padding:
                                const EdgeInsets.all(34),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.luggage_outlined,
                                  size: 52,
                                  color:
                                      TravelMateColors
                                          .teal600,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Nothing here yet',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Add an item to start your packing checklist.',
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...filtered.map(_itemCard),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _itemCard(PackingItem item) {
    final categoryIcon = switch (item.category) {
      'Clothes' =>
        Icons.checkroom_outlined,
      'Documents' =>
        Icons.description_outlined,
      'Toiletries' =>
        Icons.soap_outlined,
      'Electronics' =>
        Icons.devices_outlined,
      'Health' =>
        Icons.medical_services_outlined,
      _ =>
        Icons.inventory_2_outlined,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _toggle(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              Checkbox(
                value: item.packed,
                onChanged: (_) => _toggle(item),
                activeColor:
                    TravelMateColors.teal600,
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.packed
                      ? TravelMateColors
                          .successBackground
                      : TravelMateColors.teal100,
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Icon(
                  categoryIcon,
                  color: item.packed
                      ? TravelMateColors.success
                      : TravelMateColors.teal600,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        decoration: item.packed
                            ? TextDecoration.lineThrough
                            : null,
                        color: item.packed
                            ? TravelMateColors.textMuted
                            : TravelMateColors
                                .textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.category} · Qty ${item.quantity}',
                      style: const TextStyle(
                        color:
                            TravelMateColors
                                .textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: () => _delete(item),
                icon: const Icon(
                  Icons.delete_outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackingDialogResult {
  final String name;
  final int quantity;
  final String category;

  const _PackingDialogResult({
    required this.name,
    required this.quantity,
    required this.category,
  });
}

class _PackingItemDialog extends StatefulWidget {
  const _PackingItemDialog();

  @override
  State<_PackingItemDialog> createState() =>
      _PackingItemDialogState();
}

class _PackingItemDialogState
    extends State<_PackingItemDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;

  String _category = 'Clothes';
  bool _saving = false;

  final List<String> _categories = const [
    'Clothes',
    'Documents',
    'Toiletries',
    'Electronics',
    'Health',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController();
    _quantityController =
        TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _add() {
    if (_saving) {
      return;
    }

    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('Enter a packing item first.'),
        ),
      );
      return;
    }

    final quantity = int.tryParse(
          _quantityController.text.trim(),
        ) ??
        1;

    Navigator.of(context).pop(
      _PackingDialogResult(
        name: name,
        quantity: quantity < 1 ? 1 : quantity,
        category: _category,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add packing item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textInputAction:
                  TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Item',
                hintText: 'e.g. T-shirts',
                prefixIcon: Icon(
                  Icons.inventory_2_outlined,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              keyboardType:
                  TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                prefixIcon: Icon(
                  Icons.numbers,
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration:
                  const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(
                  Icons.category_outlined,
                ),
              ),
              items: _categories
                  .map(
                    (category) =>
                        DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null || !mounted) {
                  return;
                }

                setState(() {
                  _category = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _add,
          child: const Text('Add'),
        ),
      ],
    );
  }
}