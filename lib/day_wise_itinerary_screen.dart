import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';
import 'models.dart';
import 'storage_service.dart';
import 'sync_service.dart';

class DayWiseItineraryScreen extends StatefulWidget {
  final Trip trip;
  final VoidCallback? onBack;

  const DayWiseItineraryScreen({
    super.key,
    required this.trip,
    this.onBack,
  });

  @override
  State<DayWiseItineraryScreen> createState() =>
      _DayWiseItineraryScreenState();
}

class _DayWiseItineraryScreenState extends State<DayWiseItineraryScreen> {
  final StorageService _storage = StorageService.instance;
  final SyncService _sync = SyncService.instance;

  List<ItineraryItem> _items = [];
  int _selectedDay = 1;
  bool _loading = true;
  bool _saving = false;

  int get _dayCount {
    final start = widget.trip.startDate;
    final end = widget.trip.endDate;

    if (start == null || end == null) {
      return 1;
    }

    final count = end.difference(start).inDays + 1;

    return count.clamp(1, 31);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads the itinerary from the local SQLite database.
  ///
  /// SQLite is the immediate source for the UI so the screen remains
  /// usable without internet access.
  ///
  /// New/changed items are written through SyncService, which places
  /// them in the sync queue and uploads them to Firebase when online.
  Future<void> _load() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      await _storage.initialise();

      final items = await _storage.getItineraryItems(widget.trip.id);

      _sortItems(items);

      if (!mounted) return;

      setState(() {
        _items = items;
        _selectedDay = _selectedDay.clamp(1, _dayCount);
      });
    } catch (error) {
      debugPrint(
        'TravelMate DayWiseItinerary: SQLite load error: $error',
      );

      if (mounted) {
        _showMessage(
          'Could not load the itinerary from local storage.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _sortItems(List<ItineraryItem> items) {
    items.sort((a, b) {
      final day = a.dayNumber.compareTo(b.dayNumber);

      if (day != 0) {
        return day;
      }

      final order = a.sortOrder.compareTo(b.sortOrder);

      if (order != 0) {
        return order;
      }

      return a.time.compareTo(b.time);
    });
  }

  /// Saves an itinerary item through the central local-first sync layer.
  ///
  /// 1. SQLite is updated immediately.
  /// 2. A sync queue entry is created.
  /// 3. If Firebase is reachable, SyncService uploads it.
  /// 4. If offline, the queue remains until connectivity returns.
  Future<void> _saveItem(ItineraryItem item) async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      await _sync.saveModel(
        model: item,
        entity: 'itinerary',
        localSave: () => _storage.saveItineraryItem(item),
      );

      if (!mounted) return;

      await _load();

      if (!mounted) return;

      _showMessage(
        'Activity saved locally and queued for Firebase sync.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'TravelMate DayWiseItinerary: save error: $error',
      );
      debugPrint('$stackTrace');

      if (mounted) {
        _showMessage('Activity could not be saved.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openEditor({ItineraryItem? item}) async {
    final currentDay = item?.dayNumber ?? _selectedDay;

    final nextSortOrder = _items
            .where((value) => value.dayNumber == currentDay)
            .fold<int>(
              0,
              (max, value) =>
                  value.sortOrder > max ? value.sortOrder : max,
            ) +
        1;

    final result = await showDialog<ItineraryItem>(
      context: context,
      builder: (_) => _ActivityDialog(
        tripId: widget.trip.id,
        dayNumber: currentDay,
        item: item,
        nextSortOrder: nextSortOrder,
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    await _saveItem(result);
  }

  Future<void> _delete(ItineraryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete activity?'),
        content: Text(
          'Remove "${item.title}" from Day ${item.dayNumber}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: TravelMateColors.coral500,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _sync.deleteModel(
        entity: 'itinerary',
        tripId: item.tripId,
        entityId: item.id,
        localDelete: () => _storage.deleteItineraryItem(item.id),
      );

      if (!mounted) return;

      await _load();

      if (!mounted) return;

      _showMessage(
        'Activity deleted locally and queued for Firebase sync.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'TravelMate DayWiseItinerary: delete error: $error',
      );
      debugPrint('$stackTrace');

      if (mounted) {
        _showMessage('Activity could not be deleted.');
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final dayItems = _items
        .where((item) => item.dayNumber == _selectedDay)
        .toList();

    dayItems.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);

      if (order != 0) {
        return order;
      }

      return a.time.compareTo(b.time);
    });

    return Scaffold(
      appBar: AppBar(
        title: const _Brand(),
        leading: IconButton(
          onPressed:
              widget.onBack ?? () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _openEditor(),
        backgroundColor: TravelMateColors.coral500,
        foregroundColor: Colors.white,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white,
                  ),
                ),
              )
            : const Icon(Icons.add_rounded),
        label: const Text('Add activity'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;

          return RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                wide ? 32 : 16,
                20,
                wide ? 32 : 16,
                100,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 1180,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BackLink(
                        title: widget.trip.title,
                        onTap: widget.onBack,
                      ),
                      const SizedBox(height: 14),
                      _PageHeader(
                        trip: widget.trip,
                        onAdd: () => _openEditor(),
                      ),
                      const SizedBox(height: 20),
                      _DayTabs(
                        trip: widget.trip,
                        dayCount: _dayCount,
                        selectedDay: _selectedDay,
                        onSelected: (day) {
                          setState(() {
                            _selectedDay = day;
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      wide
                          ? Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: _Timeline(
                                    items: dayItems,
                                    loading: _loading,
                                    onEdit: (item) =>
                                        _openEditor(item: item),
                                    onDelete: _delete,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                SizedBox(
                                  width: 300,
                                  child: _Summary(
                                    items: dayItems,
                                    day: _selectedDay,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _Timeline(
                                  items: dayItems,
                                  loading: _loading,
                                  onEdit: (item) =>
                                      _openEditor(item: item),
                                  onDelete: _delete,
                                ),
                                const SizedBox(height: 16),
                                _Summary(
                                  items: dayItems,
                                  day: _selectedDay,
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                TravelMateColors.navy800,
                TravelMateColors.teal600,
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.travel_explore_rounded,
            color: Colors.white,
            size: 19,
          ),
        ),
        const SizedBox(width: 9),
        const Text(
          'TravelMate',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 19,
            color: TravelMateColors.navy800,
          ),
        ),
      ],
    );
  }
}

class _BackLink extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const _BackLink({
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:
          onTap ?? () => Navigator.of(context).maybePop(),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.arrow_back_rounded,
              size: 16,
              color: TravelMateColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              title,
              style: const TextStyle(
                color: TravelMateColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  final Trip trip;
  final VoidCallback onAdd;

  const _PageHeader({
    required this.trip,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Day-wise itinerary',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.6,
                  color: TravelMateColors.navy900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${trip.title} · ${_range(trip)}',
                style: const TextStyle(
                  fontSize: 15,
                  color: TravelMateColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onAdd,
          style: FilledButton.styleFrom(
            backgroundColor: TravelMateColors.coral500,
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add activity'),
        ),
      ],
    );
  }

  String _range(Trip trip) {
    if (trip.startDate == null || trip.endDate == null) {
      return 'Dates not set';
    }

    return '${DateFormat('dd MMM yyyy').format(trip.startDate!)} – '
        '${DateFormat('dd MMM yyyy').format(trip.endDate!)}';
  }
}

class _DayTabs extends StatelessWidget {
  final Trip trip;
  final int dayCount;
  final int selectedDay;
  final ValueChanged<int> onSelected;

  const _DayTabs({
    required this.trip,
    required this.dayCount,
    required this.selectedDay,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 66,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dayCount,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final day = index + 1;
          final date =
              trip.startDate?.add(Duration(days: index));
          final active = day == selectedDay;

          return InkWell(
            onTap: () => onSelected(day),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              constraints: const BoxConstraints(
                minWidth: 108,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 17,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: active
                    ? TravelMateColors.navy800
                    : TravelMateColors.surface,
                border: Border.all(
                  color: active
                      ? TravelMateColors.navy800
                      : TravelMateColors.border,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Day $day',
                    style: TextStyle(
                      color: active
                          ? Colors.white
                          : TravelMateColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date == null
                        ? 'Date not set'
                        : DateFormat('dd MMM').format(date),
                    style: TextStyle(
                      color: active
                          ? Colors.white
                          : TravelMateColors.navy900,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final List<ItineraryItem> items;
  final bool loading;
  final ValueChanged<ItineraryItem>? onEdit;
  final ValueChanged<ItineraryItem>? onDelete;

  const _Timeline({
    required this.items,
    required this.loading,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(42),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: TravelMateColors.backgroundAlt,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.event_note_outlined,
                  color: TravelMateColors.textMuted,
                  size: 27,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'No activities yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: TravelMateColors.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Add your first activity to start building this day.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: TravelMateColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: List.generate(
        items.length,
        (index) {
          final item = items[index];

          return _TimelineItem(
            item: item,
            isLast: index == items.length - 1,
            onEdit: onEdit == null
                ? null
                : () => onEdit!(item),
            onDelete: onDelete == null
                ? null
                : () => onDelete!(item),
          );
        },
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final ItineraryItem item;
  final bool isLast;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _TimelineItem({
    required this.item,
    required this.isLast,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final done =
        item.type.toLowerCase() == 'done';

    final tone = _tone(item.type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: done
                        ? TravelMateColors.teal600
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: TravelMateColors.teal600,
                      width: 3,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: TravelMateColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: 16,
              ),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _TypeIcon(
                        type: item.type,
                        tone: tone,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontWeight:
                                          FontWeight.w700,
                                      fontSize: 14,
                                      color:
                                          TravelMateColors
                                              .textPrimary,
                                    ),
                                  ),
                                ),
                                if (done)
                                  const _Chip(
                                    text: 'Done',
                                    tone:
                                        _ChipTone.success,
                                  )
                                else if (item
                                    .type
                                    .isNotEmpty)
                                  _Chip(
                                    text: item.type,
                                    tone: _ChipTone.neutral,
                                  ),
                              ],
                            ),
                            if (item.time.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                item.time,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.w700,
                                  color:
                                      TravelMateColors
                                          .teal600,
                                ),
                              ),
                            ],
                            if (item.location.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons
                                        .location_on_outlined,
                                    size: 14,
                                    color:
                                        TravelMateColors
                                            .textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      item.location,
                                      style:
                                          const TextStyle(
                                        color:
                                            TravelMateColors
                                                .textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (item.mapsUrl != null &&
                                item.mapsUrl!.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Row(
                                children: const [
                                  Icon(
                                    Icons.map_outlined,
                                    size: 14,
                                    color:
                                        TravelMateColors
                                            .teal600,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Google Maps link saved',
                                    style: TextStyle(
                                      color:
                                          TravelMateColors
                                              .teal600,
                                      fontSize: 11,
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (item.note.isNotEmpty) ...[
                              const SizedBox(height: 7),
                              Text(
                                item.note,
                                style: const TextStyle(
                                  color:
                                      TravelMateColors
                                          .textSecondary,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        tooltip: 'Activity actions',
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit?.call();
                          }

                          if (value == 'delete') {
                            onDelete?.call();
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
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color:
                              TravelMateColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _ChipTone _tone(String type) {
    switch (type.toLowerCase()) {
      case 'meal':
      case 'food':
      case 'breakfast':
      case 'lunch':
      case 'dinner':
        return _ChipTone.warning;

      case 'sightseeing':
      case 'landmark':
        return _ChipTone.navy;

      case 'done':
        return _ChipTone.success;

      default:
        return _ChipTone.teal;
    }
  }
}

class _TypeIcon extends StatelessWidget {
  final String type;
  final _ChipTone tone;

  const _TypeIcon({
    required this.type,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final icon = switch (type.toLowerCase()) {
      'meal' ||
      'food' ||
      'breakfast' ||
      'lunch' ||
      'dinner' =>
        Icons.restaurant_outlined,
      'sightseeing' || 'landmark' =>
        Icons.account_balance_outlined,
      'transport' || 'flight' =>
        Icons.directions_car_outlined,
      'beach' || 'activity' =>
        Icons.waves_rounded,
      'shopping' =>
        Icons.shopping_bag_outlined,
      _ =>
        Icons.event_note_outlined,
    };

    final background = switch (tone) {
      _ChipTone.warning =>
        TravelMateColors.warningBackground,
      _ChipTone.navy =>
        const Color(0xFFE7EDF4),
      _ChipTone.coral =>
        TravelMateColors.coral100,
      _ChipTone.success =>
        TravelMateColors.successBackground,
      _ChipTone.teal =>
        TravelMateColors.teal100,
      _ChipTone.neutral =>
        TravelMateColors.backgroundAlt,
    };

    final foreground = switch (tone) {
      _ChipTone.warning =>
        TravelMateColors.warning,
      _ChipTone.navy =>
        TravelMateColors.navy800,
      _ChipTone.coral =>
        TravelMateColors.coral600,
      _ChipTone.success =>
        TravelMateColors.success,
      _ChipTone.teal =>
        TravelMateColors.teal600,
      _ChipTone.neutral =>
        TravelMateColors.textSecondary,
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        icon,
        size: 19,
        color: foreground,
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final List<ItineraryItem> items;
  final int day;

  const _Summary({
    required this.items,
    required this.day,
  });

  @override
  Widget build(BuildContext context) {
    final completed = items
        .where(
          (item) =>
              item.type.toLowerCase() == 'done',
        )
        .length;

    final progress =
        items.isEmpty ? 0.0 : completed / items.length;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Day $day summary',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: TravelMateColors.navy900,
                  ),
                ),
                const SizedBox(height: 17),
                _SummaryRow(
                  label: 'Activities',
                  value: '${items.length}',
                ),
                const SizedBox(height: 10),
                _SummaryRow(
                  label: 'Completed',
                  value:
                      '$completed of ${items.length}',
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor:
                        TravelMateColors
                            .backgroundAlt,
                    valueColor:
                        const AlwaysStoppedAnimation(
                      TravelMateColors.teal600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        TravelMateColors
                            .warningBackground,
                    borderRadius:
                        BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.cloud_outlined,
                    color:
                        TravelMateColors.warning,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weather',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w800,
                          color:
                              TravelMateColors
                                  .navy900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Live weather will appear here when a weather service is connected.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color:
                              TravelMateColors
                                  .textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color:
                TravelMateColors.textSecondary,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color:
                TravelMateColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

enum _ChipTone {
  neutral,
  teal,
  navy,
  coral,
  success,
  warning,
}

class _Chip extends StatelessWidget {
  final String text;
  final _ChipTone tone;

  const _Chip({
    required this.text,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final bg = switch (tone) {
      _ChipTone.teal =>
        TravelMateColors.teal100,
      _ChipTone.navy =>
        const Color(0xFFE7EDF4),
      _ChipTone.coral =>
        TravelMateColors.coral100,
      _ChipTone.success =>
        TravelMateColors.successBackground,
      _ChipTone.warning =>
        TravelMateColors.warningBackground,
      _ChipTone.neutral =>
        TravelMateColors.backgroundAlt,
    };

    final fg = switch (tone) {
      _ChipTone.teal =>
        TravelMateColors.teal600,
      _ChipTone.navy =>
        TravelMateColors.navy800,
      _ChipTone.coral =>
        TravelMateColors.coral600,
      _ChipTone.success =>
        TravelMateColors.success,
      _ChipTone.warning =>
        TravelMateColors.warning,
      _ChipTone.neutral =>
        TravelMateColors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _ActivityDialog extends StatefulWidget {
  final String tripId;
  final int dayNumber;
  final ItineraryItem? item;
  final int nextSortOrder;

  const _ActivityDialog({
    required this.tripId,
    required this.dayNumber,
    this.item,
    required this.nextSortOrder,
  });

  @override
  State<_ActivityDialog> createState() =>
      _ActivityDialogState();
}

class _ActivityDialogState
    extends State<_ActivityDialog> {
  late final TextEditingController _title;
  late final TextEditingController _time;
  late final TextEditingController _location;
  late final TextEditingController _note;
  late final TextEditingController _mapsUrl;

  String _type = 'activity';
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final item = widget.item;

    _title = TextEditingController(
      text: item?.title ?? '',
    );

    _time = TextEditingController(
      text: item?.time ?? '',
    );

    _location = TextEditingController(
      text: item?.location ?? '',
    );

    _note = TextEditingController(
      text: item?.note ?? '',
    );

    _mapsUrl = TextEditingController(
      text: item?.mapsUrl ?? '',
    );

    _type = item?.type.isNotEmpty == true
        ? item!.type
        : 'activity';
  }

  @override
  void dispose() {
    _title.dispose();
    _time.dispose();
    _location.dispose();
    _note.dispose();
    _mapsUrl.dispose();

    super.dispose();
  }

  void _save() {
    if (_saving) return;

    final title = _title.text.trim();

    if (title.isEmpty) {
      return;
    }

    setState(() {
      _saving = true;
    });

    final old = widget.item;

    final mapsText = _mapsUrl.text.trim();

    final result = ItineraryItem(
      id: old?.id ?? StorageService.instance.newId(),
      tripId: widget.tripId,
      dayNumber:
          old?.dayNumber ?? widget.dayNumber,
      title: title,
      type: _type,
      time: _time.text.trim(),
      location: _location.text.trim(),
      note: _note.text.trim(),
      mapsUrl:
          mapsText.isEmpty ? null : mapsText,
      imageUrl: old?.imageUrl,
      sortOrder:
          old?.sortOrder ?? widget.nextSortOrder,
      updatedAt: DateTime.now(),
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.item == null
            ? 'Add activity'
            : 'Edit activity',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                textInputAction:
                    TextInputAction.next,
                decoration:
                    const InputDecoration(
                  labelText: 'Activity name',
                  hintText: 'e.g. Baga Beach',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration:
                    const InputDecoration(
                  labelText: 'Type',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'activity',
                    child: Text('Activity'),
                  ),
                  DropdownMenuItem(
                    value: 'meal',
                    child: Text('Meal'),
                  ),
                  DropdownMenuItem(
                    value: 'sightseeing',
                    child: Text('Sightseeing'),
                  ),
                  DropdownMenuItem(
                    value: 'transport',
                    child: Text('Transport'),
                  ),
                  DropdownMenuItem(
                    value: 'shopping',
                    child: Text('Shopping'),
                  ),
                  DropdownMenuItem(
                    value: 'done',
                    child: Text('Done'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _type = value;
                        });
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _time,
                textInputAction:
                    TextInputAction.next,
                decoration:
                    const InputDecoration(
                  labelText: 'Time',
                  hintText:
                      'e.g. 10:30 AM · 2 hr',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _location,
                textInputAction:
                    TextInputAction.next,
                decoration:
                    const InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(
                    Icons.location_on_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _mapsUrl,
                keyboardType:
                    TextInputType.url,
                textInputAction:
                    TextInputAction.next,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Google Maps link (optional)',
                  prefixIcon: Icon(
                    Icons.map_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLines: 3,
                textInputAction:
                    TextInputAction.newline,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Notes (optional)',
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
              : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _saving || _title.text.trim().isEmpty
                  ? null
                  : _save,
          style: FilledButton.styleFrom(
            backgroundColor:
                TravelMateColors.coral500,
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<
                            Color>(
                      Colors.white,
                    ),
                  ),
                )
              : const Text('Save activity'),
        ),
      ],
    );
  }
}