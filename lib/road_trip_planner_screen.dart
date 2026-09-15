import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_theme.dart';
import 'models.dart';
import 'storage_service.dart';
import 'sync_service.dart';

class RoadTripPlannerScreen extends StatefulWidget {
  final String tripId;

  const RoadTripPlannerScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<RoadTripPlannerScreen> createState() =>
      _RoadTripPlannerScreenState();
}

class _RoadTripPlannerScreenState
    extends State<RoadTripPlannerScreen> {
  final _storage = StorageService.instance;
  final _sync = SyncService.instance;

  List<RoadTripStop> _stops = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      await _storage.initialise();

      final stops =
          await _storage.getRoadTripStops(widget.tripId);

      stops.sort(
        (a, b) => a.sequence.compareTo(b.sequence),
      );

      if (!mounted) return;

      setState(() {
        _stops = stops;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _save(RoadTripStop stop) async {
    await _sync.saveModel(
      model: stop,
      entity: 'road_trip_stops',
      localSave: () =>
          _storage.saveRoadTripStop(stop),
    );

    await _load();
  }

  Future<void> _delete(RoadTripStop stop) async {
    await _sync.deleteModel(
      entity: 'road_trip_stops',
      tripId: widget.tripId,
      entityId: stop.id,
      localDelete: () =>
          _storage.deleteRoadTripStop(stop.id),
    );

    await _load();
  }

  Future<void> _openMaps(RoadTripStop stop) async {
    final query =
        stop.latitude != null && stop.longitude != null
            ? '${stop.latitude},${stop.longitude}'
            : (stop.address.trim().isEmpty
                ? stop.name
                : stop.address);

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      _message('Could not open Google Maps.');
    }
  }

  Future<void> _showStopDialog({
    RoadTripStop? existing,
  }) async {
    final result = await showDialog<_RoadTripDialogResult>(
      context: context,
      builder: (_) => _RoadTripStopDialog(
        existing: existing,
      ),
    );

    if (result == null) {
      return;
    }

    if (result.name.trim().isEmpty) {
      return;
    }

    final stop = RoadTripStop(
      id: existing?.id ?? _storage.newId(),
      tripId: widget.tripId,
      sequence:
          existing?.sequence ?? _stops.length + 1,
      name: result.name.trim(),
      address: result.address.trim(),
      latitude: double.tryParse(
        result.latitude.trim(),
      ),
      longitude: double.tryParse(
        result.longitude.trim(),
      ),
      stayMinutes:
          int.tryParse(result.stay.trim()) ?? 0,
      note: result.note.trim(),
      updatedAt: DateTime.now(),
    );

    await _save(stop);
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  double _distanceKm(
    RoadTripStop a,
    RoadTripStop b,
  ) {
    if (a.latitude == null ||
        a.longitude == null ||
        b.latitude == null ||
        b.longitude == null) {
      return 0;
    }

    const earthKm = 6371.0;

    final dLat =
        (b.latitude! - a.latitude!) *
            math.pi /
            180;

    final dLon =
        (b.longitude! - a.longitude!) *
            math.pi /
            180;

    final lat1 =
        a.latitude! * math.pi / 180;

    final lat2 =
        b.latitude! * math.pi / 180;

    final h =
        math.sin(dLat / 2) *
                math.sin(dLat / 2) +
            math.cos(lat1) *
                math.cos(lat2) *
                math.sin(dLon / 2) *
                math.sin(dLon / 2);

    final safeH = h.clamp(0.0, 1.0);

    return 2 *
        earthKm *
        math.asin(math.sqrt(safeH));
  }

  double get _totalDistance {
    var total = 0.0;

    for (var i = 0; i < _stops.length - 1; i++) {
      total += _distanceKm(
        _stops[i],
        _stops[i + 1],
      );
    }

    return total;
  }

  int get _totalStayMinutes =>
      _stops.fold(
        0,
        (sum, stop) => sum + stop.stayMinutes,
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: _sync.statusStream,
      initialData: _sync.status,
      builder: (context, snapshot) {
        final status =
            snapshot.data ?? _sync.status;

        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: AppBar(
            title: const Text('Road trip planner'),
            actions: [
              Padding(
                padding:
                    const EdgeInsets.only(right: 12),
                child: Chip(
                  avatar: Icon(
                    status.online
                        ? Icons.cloud_done
                        : Icons.cloud_off,
                    size: 16,
                    color: status.online
                        ? AppTheme.success
                        : AppTheme.warning,
                  ),
                  label: Text(
                    status.online
                        ? 'Online'
                        : 'Offline',
                  ),
                ),
              ),
            ],
          ),
          body: _loading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: LayoutBuilder(
                    builder:
                        (context, constraints) {
                      final wide =
                          constraints.maxWidth >=
                              900;

                      final route = _RouteCard(
                        stops: _stops,
                        onAdd: () =>
                            _showStopDialog(),
                        onEdit: (stop) =>
                            _showStopDialog(
                          existing: stop,
                        ),
                        onDelete: _delete,
                        onMaps: _openMaps,
                      );

                      final side = Column(
                        children: [
                          _TotalsCard(
                            distance:
                                _totalDistance,
                            stops: _stops.length,
                            stayMinutes:
                                _totalStayMinutes,
                          ),
                          const SizedBox(height: 16),
                          const _LegendCard(),
                        ],
                      );

                      return SingleChildScrollView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        padding:
                            const EdgeInsets.all(24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(
                              maxWidth: 1200,
                            ),
                            child: wide
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Expanded(
                                        child: route,
                                      ),
                                      const SizedBox(
                                        width: 24,
                                      ),
                                      SizedBox(
                                        width: 320,
                                        child: side,
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      route,
                                      const SizedBox(
                                        height: 20,
                                      ),
                                      side,
                                    ],
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
          floatingActionButton:
              FloatingActionButton.extended(
            onPressed: () =>
                _showStopDialog(),
            backgroundColor: AppTheme.coral,
            foregroundColor: Colors.white,
            icon: const Icon(
              Icons.add_rounded,
            ),
            label: const Text('Add stop'),
          ),
        );
      },
    );
  }
}

class _RoadTripDialogResult {
  final String name;
  final String address;
  final String latitude;
  final String longitude;
  final String stay;
  final String note;

  const _RoadTripDialogResult({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.stay,
    required this.note,
  });
}

class _RoadTripStopDialog extends StatefulWidget {
  final RoadTripStop? existing;

  const _RoadTripStopDialog({
    this.existing,
  });

  @override
  State<_RoadTripStopDialog> createState() =>
      _RoadTripStopDialogState();
}

class _RoadTripStopDialogState
    extends State<_RoadTripStopDialog> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _stay;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _name = TextEditingController(
      text: existing?.name ?? '',
    );

    _address = TextEditingController(
      text: existing?.address ?? '',
    );

    _latitude = TextEditingController(
      text: existing?.latitude?.toString() ?? '',
    );

    _longitude = TextEditingController(
      text: existing?.longitude?.toString() ?? '',
    );

    _stay = TextEditingController(
      text: existing?.stayMinutes.toString() ?? '0',
    );

    _note = TextEditingController(
      text: existing?.note ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _stay.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a stop name first.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _RoadTripDialogResult(
        name: _name.text,
        address: _address.text,
        latitude: _latitude.text,
        longitude: _longitude.text,
        stay: _stay.text,
        note: _note.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Add stop'
            : 'Edit stop',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _field(
                _name,
                'Stop name',
                Icons.location_on_outlined,
              ),
              _field(
                _address,
                'Address',
                Icons.place_outlined,
              ),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _latitude,
                      'Latitude',
                      Icons.explore_outlined,
                      keyboard:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      _longitude,
                      'Longitude',
                      Icons.explore_outlined,
                      keyboard:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                ],
              ),
              _field(
                _stay,
                'Stay time (minutes)',
                Icons.schedule_outlined,
                keyboard:
                    TextInputType.number,
              ),
              _field(
                _note,
                'Notes',
                Icons.notes_outlined,
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
          onPressed: _save,
          child: const Text('Save stop'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboard,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final List<RoadTripStop> stops;
  final VoidCallback onAdd;
  final ValueChanged<RoadTripStop> onEdit;
  final ValueChanged<RoadTripStop> onDelete;
  final ValueChanged<RoadTripStop> onMaps;

  const _RouteCard({
    required this.stops,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onMaps,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Your route',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(
                    Icons.add_rounded,
                  ),
                  label: const Text(
                    'Add stop',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Stops are ordered by sequence. Distance is estimated when coordinates are available.',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 20),
            if (stops.isEmpty)
              const _EmptyRoute()
            else
              for (var i = 0;
                  i < stops.length;
                  i++) ...[
                _StopTile(
                  stop: stops[i],
                  index: i,
                  onMaps: () =>
                      onMaps(stops[i]),
                  onEdit: () =>
                      onEdit(stops[i]),
                  onDelete: () =>
                      onDelete(stops[i]),
                ),
                if (i != stops.length - 1)
                  const Padding(
                    padding:
                        EdgeInsets.only(left: 23),
                    child: SizedBox(
                      height: 28,
                      child:
                          VerticalDivider(
                        width: 1,
                      ),
                    ),
                  ),
              ],
          ],
        ),
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  final RoadTripStop stop;
  final int index;
  final VoidCallback onMaps;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StopTile({
    required this.stop,
    required this.index,
    required this.onMaps,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration:
              const BoxDecoration(
            color: AppTheme.teal100,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: AppTheme.teal,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  stop.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (stop.address.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    stop.address,
                    style: const TextStyle(
                      color:
                          AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (stop.note.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    stop.note,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  children: [
                    if (stop.stayMinutes > 0)
                      _InfoChip(
                        icon:
                            Icons.schedule_rounded,
                        label:
                            '${stop.stayMinutes} min stay',
                      ),
                    if (stop.latitude != null &&
                        stop.longitude != null)
                      const _InfoChip(
                        icon:
                            Icons.gps_fixed_rounded,
                        label:
                            'Coordinates saved',
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  children: [
                    TextButton.icon(
                      onPressed: onMaps,
                      icon: const Icon(
                        Icons.map_outlined,
                        size: 17,
                      ),
                      label: const Text(
                        'Open in Maps',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 17,
                      ),
                      label: const Text(
                        'Edit',
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bgAlt,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: AppTheme.teal,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color:
                  AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final double distance;
  final int stops;
  final int stayMinutes;

  const _TotalsCard({
    required this.distance,
    required this.stops,
    required this.stayMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Trip totals',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _TotalRow(
              icon: Icons.route_rounded,
              label: 'Estimated distance',
              value: distance > 0
                  ? '${distance.toStringAsFixed(1)} km'
                  : '—',
            ),
            const Divider(height: 24),
            _TotalRow(
              icon:
                  Icons.location_on_outlined,
              label: 'Stops',
              value: '$stops',
            ),
            const Divider(height: 24),
            _TotalRow(
              icon:
                  Icons.schedule_rounded,
              label: 'Planned stay time',
              value: stayMinutes > 0
                  ? _formatMinutes(
                      stayMinutes,
                    )
                  : '—',
            ),
          ],
        ),
      ),
    );
  }

  static String _formatMinutes(
    int minutes,
  ) {
    final h = minutes ~/ 60;
    final m = minutes % 60;

    if (h == 0) return '$m min';
    if (m == 0) return '$h h';

    return '$h h $m min';
  }
}

class _TotalRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TotalRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppTheme.teal,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color:
                  AppTheme.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _LegendCard extends StatelessWidget {
  const _LegendCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Tip',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add latitude and longitude when you want TravelMate to calculate an approximate distance between stops.',
              style: TextStyle(
                color:
                    AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRoute extends StatelessWidget {
  const _EmptyRoute();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.alt_route_rounded,
            size: 44,
            color: AppTheme.teal,
          ),
          SizedBox(height: 10),
          Text(
            'No stops yet',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Add your starting point, stops and destination.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}