import 'dart:async';

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'models.dart';
import 'storage_service.dart';

/// Search/filter screen corresponding to 16_trip_search.html.
///
/// Reads actual Trip records from the local SQLite cache.
class TripSearchScreen extends StatefulWidget {
  final ValueChanged<Trip>? onTripSelected;
  final VoidCallback? onCreateTrip;

  const TripSearchScreen({
    super.key,
    this.onTripSelected,
    this.onCreateTrip,
  });

  @override
  State<TripSearchScreen> createState() => _TripSearchScreenState();
}

class _TripSearchScreenState extends State<TripSearchScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<Trip> _trips = [];
  String _selectedFilter = 'all';
  bool _sortAscending = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);
    _loadTrips();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();

    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();

    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(
      const Duration(milliseconds: 250),
      _loadTrips,
    );
  }

  Future<void> _loadTrips() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final trips = await StorageService.instance.getTrips(
        search: _searchController.text.trim(),
      );

      trips.sort((a, b) {
        final first = a.startDate ?? a.updatedAt;
        final second = b.startDate ?? b.updatedAt;

        final result = first.compareTo(second);

        return _sortAscending ? result : -result;
      });

      if (!mounted) return;

      setState(() {
        _trips = trips;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() => _loading = false);

      _showMessage(
        'Unable to load trips from local storage.',
      );
    }
  }

  List<Trip> get _visibleTrips {
    if (_selectedFilter == 'all') {
      return _trips;
    }

    return _trips.where((trip) {
      return _tripStatus(trip) == _selectedFilter;
    }).toList();
  }

  String _tripStatus(Trip trip) {
    final now = DateTime.now();
    final start = trip.startDate;
    final end = trip.endDate;

    if (start == null && end == null) {
      return trip.status.isEmpty ? 'ongoing' : trip.status;
    }

    if (start != null && now.isBefore(start)) {
      return 'upcoming';
    }

    if (end != null && now.isAfter(end)) {
      return 'completed';
    }

    return 'ongoing';
  }

  int _count(String status) {
    if (status == 'all') {
      return _trips.length;
    }

    return _trips.where((trip) {
      return _tripStatus(trip) == status;
    }).length;
  }

  void _toggleSort() {
    setState(() {
      _sortAscending = !_sortAscending;
    });

    _loadTrips();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleTrips;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 24,
        title: const _Brand(),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () {
              _searchController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _searchController.text.length,
              );
            },
            icon: const Icon(
              Icons.search_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              _showMessage(
                'Notifications will appear here.',
              );
            },
            icon: const Icon(
              Icons.notifications_none_rounded,
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 20),
            child: _Avatar(
              initials: 'PS',
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: TravelMateColors.border,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTrips,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal =
                constraints.maxWidth >= 900 ? 32.0 : 16.0;

            final maxWidth =
                constraints.maxWidth >= 1240
                    ? 1180.0
                    : double.infinity;

            return ListView(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                28,
                horizontal,
                40,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxWidth,
                    ),
                    child: _Header(
                      onCreateTrip: widget.onCreateTrip,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxWidth,
                    ),
                    child: _Toolbar(
                      controller: _searchController,
                      sortAscending: _sortAscending,
                      onSort: _toggleSort,
                      onFilter: () {
                        _showFilterSheet(context);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxWidth,
                    ),
                    child: _FilterChips(
                      selected: _selectedFilter,
                      count: _count,
                      onSelected: (value) {
                        setState(() {
                          _selectedFilter = value;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxWidth,
                    ),
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(64),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : visible.isEmpty
                            ? _EmptyState(
                                onCreateTrip: widget.onCreateTrip,
                              )
                            : _TripGrid(
                                trips: visible,
                                onTripSelected:
                                    widget.onTripSelected,
                              ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showFilterSheet(
    BuildContext context,
  ) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Filter trips',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: TravelMateColors.navy900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                RadioGroup<String>(
                  groupValue: _selectedFilter,
                  onChanged: (value) {
                    if (value != null) {
                      Navigator.pop(context, value);
                    }
                  },
                  child: Column(
                    children: [
                      for (final value in [
                        'all',
                        'upcoming',
                        'ongoing',
                        'completed',
                      ])
                        RadioListTile<String>(
                          value: value,
                          title: Text(
                            _labelForFilter(value),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _selectedFilter = result;
      });
    }
  }

  String _labelForFilter(String value) {
    switch (value) {
      case 'upcoming':
        return 'Upcoming';
      case 'ongoing':
        return 'Ongoing';
      case 'completed':
        return 'Completed';
      default:
        return 'All trips';
    }
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

class _Avatar extends StatelessWidget {
  final String initials;

  const _Avatar({
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 17,
      backgroundColor: TravelMateColors.teal100,
      foregroundColor: TravelMateColors.teal600,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback? onCreateTrip;

  const _Header({
    this.onCreateTrip,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My trips',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: TravelMateColors.navy900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Search, filter and jump back into any trip.',
                style: TextStyle(
                  fontSize: 15,
                  color: TravelMateColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: onCreateTrip,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(
              TravelMateColors.coral500,
            ),
          ),
          icon: const Icon(
            Icons.add_rounded,
          ),
          label: const Text(
            'New trip',
          ),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  final TextEditingController controller;
  final bool sortAscending;
  final VoidCallback onSort;
  final VoidCallback onFilter;

  const _Toolbar({
    required this.controller,
    required this.sortAscending,
    required this.onSort,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText:
                  'Search trips by name or destination...',
              prefixIcon: Icon(
                Icons.search_rounded,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: onFilter,
          icon: const Icon(
            Icons.tune_rounded,
          ),
          label: const Text(
            'Filter',
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: onSort,
          icon: const Icon(
            Icons.swap_vert_rounded,
          ),
          label: Text(
            sortAscending ? 'Date ↑' : 'Date ↓',
          ),
        ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  final String selected;
  final int Function(String) count;
  final ValueChanged<String> onSelected;

  const _FilterChips({
    required this.selected,
    required this.count,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const values = [
      'all',
      'upcoming',
      'ongoing',
      'completed',
    ];

    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: values.map((value) {
            final active = value == selected;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: active,
                label: Text(
                  '${_label(value)} (${count(value)})',
                ),
                onSelected: (_) {
                  onSelected(value);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _label(String value) {
    switch (value) {
      case 'upcoming':
        return 'Upcoming';
      case 'ongoing':
        return 'Ongoing';
      case 'completed':
        return 'Completed';
      default:
        return 'All';
    }
  }
}

class _TripGrid extends StatelessWidget {
  final List<Trip> trips;
  final ValueChanged<Trip>? onTripSelected;

  const _TripGrid({
    required this.trips,
    this.onTripSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final columns = width >= 1000
            ? 3
            : width >= 650
                ? 2
                : 1;

        const gap = 20.0;

        final cardWidth =
            (width - ((columns - 1) * gap)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: trips.map((trip) {
            return SizedBox(
              width: cardWidth,
              child: _TripCard(
                trip: trip,
                onTap: () {
                  onTripSelected?.call(trip);
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback? onTap;

  const _TripCard({
    required this.trip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = _status(trip);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 140,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _NetworkImage(
                    url: trip.coverImageUrl ??
                        _fallbackImage(trip),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _StatusChip(
                      status: status,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.title.isEmpty
                        ? 'Untitled trip'
                        : trip.title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: TravelMateColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _Meta(
                    icon:
                        Icons.calendar_today_rounded,
                    text: _dateRange(trip),
                  ),
                  const SizedBox(height: 5),
                  _Meta(
                    icon:
                        Icons.location_on_outlined,
                    text: trip.destination.isEmpty
                        ? 'Destination not set'
                        : trip.destination,
                    muted: true,
                  ),
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(vertical: 12),
                    child: Divider(
                      height: 1,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.people_outline_rounded,
                        size: 15,
                        color:
                            TravelMateColors.textMuted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        trip.ownerId.isEmpty
                            ? 'Trip'
                            : 'Shared trip',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color:
                              TravelMateColors.textMuted,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 17,
                        color:
                            TravelMateColors.teal600,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fallbackImage(Trip trip) {
    final text = trip.destination.toLowerCase();

    if (text.contains('goa')) {
      return 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?auto=format&fit=crop&w=800&q=80';
    }

    if (text.contains('rajasthan') ||
        text.contains('jaipur')) {
      return 'https://images.unsplash.com/photo-1477587458883-47145ed94245?auto=format&fit=crop&w=800&q=80';
    }

    if (text.contains('kerala') ||
        text.contains('kochi')) {
      return 'https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?auto=format&fit=crop&w=800&q=80';
    }

    if (text.contains('manali')) {
      return 'https://images.unsplash.com/photo-1626621341517-bbf3d9990a23?auto=format&fit=crop&w=800&q=80';
    }

    return 'https://images.unsplash.com/photo-1500534623283-312aade485b7?auto=format&fit=crop&w=800&q=80';
  }

  String _dateRange(Trip trip) {
    final start = trip.startDate;
    final end = trip.endDate;

    if (start == null && end == null) {
      return 'Dates not set';
    }

    if (start != null && end != null) {
      return '${start.day}/${start.month}/${start.year} – '
          '${end.day}/${end.month}/${end.year}';
    }

    final date = start ?? end!;

    return '${date.day}/${date.month}/${date.year}';
  }

  String _status(Trip trip) {
    final now = DateTime.now();

    if (trip.startDate != null &&
        now.isBefore(trip.startDate!)) {
      return 'upcoming';
    }

    if (trip.endDate != null &&
        now.isAfter(trip.endDate!)) {
      return 'completed';
    }

    return 'ongoing';
  }
}

class _NetworkImage extends StatelessWidget {
  final String url;

  const _NetworkImage({
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Container(
          color: TravelMateColors.backgroundAlt,
          alignment: Alignment.center,
          child: const Icon(
            Icons.landscape_rounded,
            size: 42,
            color: TravelMateColors.textMuted,
          ),
        );
      },
      loadingBuilder:
          (context, child, progress) {
        if (progress == null) {
          return child;
        }

        return Container(
          color: TravelMateColors.backgroundAlt,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isUpcoming = status == 'upcoming';
    final isOngoing = status == 'ongoing';

    final background = isUpcoming
        ? TravelMateColors.teal100
        : isOngoing
            ? TravelMateColors.warningBackground
            : TravelMateColors.backgroundAlt;

    final foreground = isUpcoming
        ? TravelMateColors.teal600
        : isOngoing
            ? TravelMateColors.warning
            : TravelMateColors.textSecondary;

    final displayStatus = status.isEmpty
        ? 'Trip'
        : '${status[0].toUpperCase()}'
            '${status.substring(1)}';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool muted;

  const _Meta({
    required this.icon,
    required this.text,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = muted
        ? TravelMateColors.textMuted
        : TravelMateColors.textSecondary;

    return Row(
      children: [
        Icon(
          icon,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback? onCreateTrip;

  const _EmptyState({
    this.onCreateTrip,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 56,
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color:
                    TravelMateColors.backgroundAlt,
                borderRadius:
                    BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.luggage_outlined,
                size: 27,
                color:
                    TravelMateColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No trips found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color:
                    TravelMateColors.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Try another search or create your first trip.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color:
                    TravelMateColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onCreateTrip,
              icon: const Icon(
                Icons.add_rounded,
              ),
              label: const Text(
                'Create trip',
              ),
            ),
          ],
        ),
      ),
    );
  }
}