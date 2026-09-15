import 'dart:async';

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'models.dart';
import 'storage_service.dart';
import 'sync_service.dart';

class OfflineStorageScreen extends StatefulWidget {
  const OfflineStorageScreen({
    super.key,
    required this.tripId,
  });

  final String tripId;

  @override
  State<OfflineStorageScreen> createState() =>
      _OfflineStorageScreenState();
}

class _OfflineStorageScreenState extends State<OfflineStorageScreen> {
  final _storage = StorageService.instance;
  final _sync = SyncService.instance;

  StreamSubscription<SyncStatus>? _syncSubscription;

  SyncStatus _status = const SyncStatus(
    online: false,
    syncing: false,
    pendingItems: 0,
  );

  Trip? _trip;

  int _storageBytes = 0;
  int _documentBytes = 0;
  int _imageBytes = 0;

  int _itineraryCount = 0;
  int _bookingCount = 0;
  int _noteCount = 0;
  int _expenseCount = 0;
  int _packingCount = 0;
  int _todoCount = 0;
  int _memberCount = 0;
  int _locationCount = 0;

  bool _loading = true;
  DateTime? _lastLoadedAt;

  @override
  void initState() {
    super.initState();

    _status = _sync.status;

    _syncSubscription = _sync.statusStream.listen((status) {
      if (!mounted) return;

      setState(() {
        _status = status;
      });
    });

    _load();
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _storage.initialise();

      final trip = await _storage.getTrip(widget.tripId);
      final files =
          await _storage.getLocalFiles(widget.tripId);
      final itinerary =
          await _storage.getItineraryItems(widget.tripId);
      final bookings =
          await _storage.getBookings(widget.tripId);
      final notes =
          await _storage.getNotes(widget.tripId);
      final expenses =
          await _storage.getExpenses(widget.tripId);
      final packing =
          await _storage.getPackingItems(widget.tripId);
      final todos =
          await _storage.getTodos(widget.tripId);
      final members =
          await _storage.getMembers(widget.tripId);
      final locations =
          await _storage.getLocations(widget.tripId);

      var documentBytes = 0;
      var imageBytes = 0;

      for (final file in files) {
        final lower =
            '${file.fileName} ${file.mimeType}'.toLowerCase();

        if (lower.contains('image') ||
            RegExp(
              r'\.(jpg|jpeg|png|webp|gif|heic)$',
            ).hasMatch(lower)) {
          imageBytes += file.sizeBytes;
        } else {
          documentBytes += file.sizeBytes;
        }
      }

      if (!mounted) return;

      setState(() {
        _trip = trip;

        _storageBytes =
            documentBytes + imageBytes;

        _documentBytes = documentBytes;
        _imageBytes = imageBytes;

        _itineraryCount = itinerary.length;
        _bookingCount = bookings.length;
        _noteCount = notes.length;
        _expenseCount = expenses.length;
        _packingCount = packing.length;
        _todoCount = todos.length;
        _memberCount = members.length;
        _locationCount = locations.length;

        _lastLoadedAt = DateTime.now();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _syncNow() async {
    if (!_status.online) {
      _message(
        'You are offline. Changes will remain queued until a connection is available.',
      );
      return;
    }

    await _sync.flushQueue();
    await _load();

    if (mounted) {
      _message('Sync check completed.');
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  String _relativeTime(DateTime? value) {
    if (value == null) {
      return 'Not checked yet';
    }

    final difference =
        DateTime.now().difference(value);

    if (difference.inSeconds < 10) {
      return 'Just now';
    }

    if (difference.inMinutes < 1) {
      return '${difference.inSeconds}s ago';
    }

    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }

    if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    }

    return '${difference.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final usedMb =
        _storageBytes / (1024 * 1024);

    const displayCapacityMb = 5120.0;

    final percentage =
        (usedMb / displayCapacityMb)
            .clamp(0.0, 1.0)
            .toDouble();

    final tripName =
        _trip?.title.isNotEmpty == true
            ? _trip!.title
            : 'Current trip';

    final destination =
        _trip?.destination.isNotEmpty == true
            ? _trip!.destination
            : 'Your trip';

    return Scaffold(
      appBar: AppBar(
        title: const _BrandTitle(),

        // Prevents excessive default title spacing.
        titleSpacing: 0,

        actions: [
          _ConnectionChip(
            status: _status,
          ),

          const SizedBox(width: 8),

          Padding(
            padding: const EdgeInsets.only(
              right: 10,
            ),
            child: const _ProfileAvatar(),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  20,
                  24,
                  20,
                  40,
                ),
                children: [
                  _PageHeader(
                    tripName: tripName,
                    destination: destination,
                  ),

                  const SizedBox(height: 20),

                  _OfflineBanner(
                    online: _status.online,
                    pending: _status.pendingItems,
                  ),

                  const SizedBox(height: 20),

                  LayoutBuilder(
                    builder: (
                      context,
                      constraints,
                    ) {
                      final wide =
                          constraints.maxWidth >= 900;

                      final children = [
                        _StorageCard(
                          storageBytes: _storageBytes,
                          documentBytes: _documentBytes,
                          imageBytes: _imageBytes,
                          itineraryCount:
                              _itineraryCount,
                          percentage: percentage,
                          relativeTime:
                              _relativeTime(
                            _lastLoadedAt,
                          ),
                        ),

                        _SavedOfflineCard(
                          itineraryCount:
                              _itineraryCount,
                          bookingCount:
                              _bookingCount,
                          noteCount:
                              _noteCount,
                          expenseCount:
                              _expenseCount,
                          packingCount:
                              _packingCount,
                          todoCount:
                              _todoCount,
                          memberCount:
                              _memberCount,
                          locationCount:
                              _locationCount,
                          pending:
                              _status.pendingItems,
                        ),
                      ];

                      if (wide) {
                        return Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: children[0],
                            ),
                            const SizedBox(
                              width: 20,
                            ),
                            Expanded(
                              child: children[1],
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          children[0],
                          const SizedBox(
                            height: 20,
                          ),
                          children[1],
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  _OfflineActions(
                    online: _status.online,
                    syncing: _status.syncing,
                    pending:
                        _status.pendingItems,
                    onSync: _syncNow,
                    onRefresh: _load,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Responsive TravelMate branding.
///
/// The original header had fixed spacing that could cause a small
/// RenderFlex overflow on narrow phones.
class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    final width =
        MediaQuery.sizeOf(context).width;

    final compact = width < 390;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 32 : 34,
          height: compact ? 32 : 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                TravelMateColors.teal600,
                TravelMateColors.navy800,
              ],
            ),
            borderRadius:
                BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.travel_explore_rounded,
            color: Colors.white,
            size: compact ? 19 : 20,
          ),
        ),

        SizedBox(
          width: compact ? 7 : 10,
        ),

        Text(
          'TravelMate',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: compact ? 18 : 20,
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 17,
      backgroundColor:
          TravelMateColors.teal100,
      foregroundColor:
          TravelMateColors.teal600,
      child: const Text(
        'PS',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Responsive Online/Offline connection chip.
class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({
    required this.status,
  });

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 390;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: status.online
            ? TravelMateColors.successBackground
            : TravelMateColors.warningBackground,
        borderRadius:
            BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status.online
                ? Icons.wifi_rounded
                : Icons.wifi_off_rounded,
            size: compact ? 13 : 14,
            color: status.online
                ? TravelMateColors.success
                : TravelMateColors.warning,
          ),

          const SizedBox(width: 5),

          Text(
            status.online
                ? 'Online'
                : 'Offline',
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
              color: status.online
                  ? TravelMateColors.success
                  : TravelMateColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.tripName,
    required this.destination,
  });

  final String tripName;
  final String destination;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          '‹  $tripName',
          style: const TextStyle(
            color:
                TravelMateColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 14),

        const Text(
          'Offline mode',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color:
                TravelMateColors.textPrimary,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Your important travel information is '
          'available even without internet. · '
          '$destination',
          style: const TextStyle(
            color:
                TravelMateColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({
    required this.online,
    required this.pending,
  });

  final bool online;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final title = online
        ? 'Connected — offline data is ready'
        : 'Offline mode active';

    final subtitle = online
        ? (pending == 0
            ? 'Your local trip data is up to date '
                'with no queued changes.'
            : '$pending local change'
                '${pending == 1 ? '' : 's'} '
                'waiting to sync.')
        : 'Your saved itinerary, bookings, notes '
            'and checklists remain available on '
            'this device.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
                    horizontal: 13,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: .12,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      999,
                    ),
                  ),
                  child: Row(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Icon(
                        online
                            ? Icons.wifi_rounded
                            : Icons.wifi_off_rounded,
                        size: 16,
                        color: Colors.white,
                      ),

                      const SizedBox(width: 7),

                      Text(
                        online
                            ? 'Online'
                            : 'Offline mode active',
                        style:
                            const TextStyle(
                          color: Colors.white,
                          fontWeight:
                              FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  title,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  subtitle,
                  style:
                      const TextStyle(
                    color:
                        Color(0xFFC9D6E0),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 20),

          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: .12,
              ),
              borderRadius:
                  BorderRadius.circular(18),
            ),
            child: Icon(
              online
                  ? Icons.cloud_done_rounded
                  : Icons.cloud_off_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({
    required this.storageBytes,
    required this.documentBytes,
    required this.imageBytes,
    required this.itineraryCount,
    required this.percentage,
    required this.relativeTime,
  });

  final int storageBytes;
  final int documentBytes;
  final int imageBytes;
  final int itineraryCount;
  final double percentage;
  final String relativeTime;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Storage usage',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 18),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Used on this device',
                  style: TextStyle(
                    color:
                        TravelMateColors.textSecondary,
                  ),
                ),
                Text(
                  _format(storageBytes),
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            ClipRRect(
              borderRadius:
                  BorderRadius.circular(99),
              child:
                  LinearProgressIndicator(
                value: percentage,
                minHeight: 9,
                backgroundColor:
                    TravelMateColors
                        .backgroundAlt,
                valueColor:
                    const AlwaysStoppedAnimation(
                  TravelMateColors.teal600,
                ),
              ),
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: _Metric(
                    value:
                        _format(documentBytes),
                    label: 'Documents',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    value:
                        _format(imageBytes),
                    label: 'Images',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    value:
                        '$itineraryCount',
                    label:
                        'Itinerary items',
                  ),
                ),
              ],
            ),

            const Divider(height: 30),

            Row(
              children: [
                const Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color:
                      TravelMateColors
                          .textSecondary,
                ),

                const SizedBox(width: 8),

                const Text(
                  'Last checked',
                  style: TextStyle(
                    color:
                        TravelMateColors
                            .textSecondary,
                  ),
                ),

                const Spacer(),

                Text(
                  relativeTime,
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _format(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }

    if (bytes <
        1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          label,
          style: const TextStyle(
            color:
                TravelMateColors.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _SavedOfflineCard extends StatelessWidget {
  const _SavedOfflineCard({
    required this.itineraryCount,
    required this.bookingCount,
    required this.noteCount,
    required this.expenseCount,
    required this.packingCount,
    required this.todoCount,
    required this.memberCount,
    required this.locationCount,
    required this.pending,
  });

  final int itineraryCount;
  final int bookingCount;
  final int noteCount;
  final int expenseCount;
  final int packingCount;
  final int todoCount;
  final int memberCount;
  final int locationCount;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final items = [
      _OfflineItem(
        Icons.route_rounded,
        'Itinerary — $itineraryCount '
            'item${itineraryCount == 1 ? '' : 's'}',
        true,
      ),
      _OfflineItem(
        Icons.folder_copy_rounded,
        'Booking documents — $bookingCount '
            'record${bookingCount == 1 ? '' : 's'}',
        true,
      ),
      _OfflineItem(
        Icons.sticky_note_2_rounded,
        'Travel notes — $noteCount',
        true,
      ),
      _OfflineItem(
        Icons.account_balance_wallet_rounded,
        'Expense log — $expenseCount',
        pending == 0,
      ),
      _OfflineItem(
        Icons.backpack_rounded,
        'Packing checklist — $packingCount',
        true,
      ),
      _OfflineItem(
        Icons.checklist_rounded,
        'Travel to-do — $todoCount',
        true,
      ),
      _OfflineItem(
        Icons.people_alt_rounded,
        'Trip members — $memberCount',
        true,
      ),
      _OfflineItem(
        Icons.place_rounded,
        'Saved locations — $locationCount',
        true,
      ),
    ];

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              "What's saved offline",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            ...items.map(
              (item) => _SavedRow(
                item: item,
                pending: pending,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineItem {
  const _OfflineItem(
    this.icon,
    this.label,
    this.synced,
  );

  final IconData icon;
  final String label;
  final bool synced;
}

class _SavedRow extends StatelessWidget {
  const _SavedRow({
    required this.item,
    required this.pending,
  });

  final _OfflineItem item;
  final int pending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical: 11,
      ),
      decoration:
          const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
                TravelMateColors
                    .backgroundAlt,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: item.synced
                  ? TravelMateColors
                      .successBackground
                  : TravelMateColors
                      .warningBackground,
              borderRadius:
                  BorderRadius.circular(9),
            ),
            child: Icon(
              item.synced
                  ? Icons.check_circle_rounded
                  : Icons.schedule_rounded,
              size: 17,
              color: item.synced
                  ? TravelMateColors.success
                  : TravelMateColors.warning,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              item.label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(width: 8),

          _StatusChip(
            text: item.synced
                ? 'Saved'
                : 'Waiting to sync',
            warning: !item.synced,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.text,
    this.warning = false,
  });

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: warning
            ? TravelMateColors
                .warningBackground
            : TravelMateColors
                .successBackground,
        borderRadius:
            BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: warning
              ? TravelMateColors.warning
              : TravelMateColors.success,
          fontSize: 11,
          fontWeight:
              FontWeight.w800,
        ),
      ),
    );
  }
}

class _OfflineActions extends StatelessWidget {
  const _OfflineActions({
    required this.online,
    required this.syncing,
    required this.pending,
    required this.onSync,
    required this.onRefresh,
  });

  final bool online;
  final bool syncing;
  final int pending;

  final VoidCallback onSync;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final compact =
                constraints.maxWidth < 600;

            if (compact) {
              return Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Text(
                    pending == 0
                        ? 'No changes are waiting '
                            'to sync.'
                        : '$pending change'
                            '${pending == 1 ? '' : 's'} '
                            'are queued for Firebase sync.',
                    style: const TextStyle(
                      color:
                          TravelMateColors
                              .textSecondary,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child:
                            OutlinedButton.icon(
                          onPressed: onRefresh,
                          icon: const Icon(
                            Icons.refresh_rounded,
                          ),
                          label:
                              const Text(
                            'Refresh',
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child:
                            FilledButton.icon(
                          onPressed:
                              syncing
                                  ? null
                                  : onSync,
                          icon: syncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                        Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.sync_rounded,
                                ),
                          label: Text(
                            online
                                ? 'Sync now'
                                : 'Offline',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: Text(
                    pending == 0
                        ? 'No changes are waiting '
                            'to sync.'
                        : '$pending change'
                            '${pending == 1 ? '' : 's'} '
                            'are queued for Firebase sync.',
                    style: const TextStyle(
                      color:
                          TravelMateColors
                              .textSecondary,
                    ),
                  ),
                ),

                OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(
                    Icons.refresh_rounded,
                  ),
                  label:
                      const Text('Refresh'),
                ),

                const SizedBox(width: 10),

                FilledButton.icon(
                  onPressed:
                      syncing ? null : onSync,
                  icon: syncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.sync_rounded,
                        ),
                  label: Text(
                    online
                        ? 'Sync now'
                        : 'Offline',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}