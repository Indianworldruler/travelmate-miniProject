import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import 'app_theme.dart';
import 'models.dart';
import 'storage_service.dart';
import 'sync_service.dart';

class BookingMasterFolderScreen extends StatefulWidget {
  const BookingMasterFolderScreen({
    super.key,
    required this.tripId,
    this.onBack,
  });

  final String tripId;
  final VoidCallback? onBack;

  @override
  State<BookingMasterFolderScreen> createState() =>
      _BookingMasterFolderScreenState();
}

class _BookingMasterFolderScreenState
    extends State<BookingMasterFolderScreen> {
  final _storage = StorageService.instance;
  final _sync = SyncService.instance;

  List<Booking> _bookings = [];
  String _tab = 'all';
  String _query = '';
  bool _loading = true;
  bool _uploading = false;
  bool _online = false;

  StreamSubscription<SyncStatus>? _statusSub;
  StreamSubscription<Map<String, dynamic>>? _remoteSub;

  @override
  void initState() {
    super.initState();

    _load();

    _online = _sync.status.online;

    _statusSub = _sync.statusStream.listen((status) {
      if (!mounted) return;

      setState(() {
        _online = status.online;
      });
    });

    _remoteSub = _sync.watchCollection(
      entity: 'bookings',
      tripId: widget.tripId,
      onChanged: (data) async {
        await _sync.cacheRemoteCollection(
          entity: 'bookings',
          tripId: widget.tripId,
          remoteValues: data,
        );

        await _load();
      },
    );
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _remoteSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final bookings = await _storage.getBookings(widget.tripId);

    if (!mounted) return;

    setState(() {
      _bookings = bookings;
      _loading = false;
    });
  }

  List<Booking> get _visibleBookings {
    final q = _query.trim().toLowerCase();

    return _bookings.where((booking) {
      final type = _normaliseType(booking.type);

      final tabMatch = _tab == 'all' || type == _tab;

      final text =
          '${booking.title} '
          '${booking.type} '
          '${booking.referenceNumber} '
          '${booking.fileName} '
          '${booking.notes}'
              .toLowerCase();

      return tabMatch && (q.isEmpty || text.contains(q));
    }).toList();
  }

  String _normaliseType(String type) {
    final value = type.toLowerCase();

    if (value.contains('flight')) {
      return 'flights';
    }

    if (value.contains('hotel') || value.contains('stay')) {
      return 'hotels';
    }

    if (value.contains('activity') ||
        value.contains('tour') ||
        value.contains('cruise')) {
      return 'activities';
    }

    return 'other';
  }

  Future<void> _uploadDocument() async {
    if (_uploading) return;

    setState(() {
      _uploading = true;
    });

    try {
      final result = await FilePicker.pickFiles();

      if (result.isEmpty) return;

      final picked = result.single;

      if (picked.path == null) return;

      final source = File(picked.path!);

      final category = await _chooseCategory();

      if (category == null) return;

      final localDocument = await _storage.saveLocalFile(
        tripId: widget.tripId,
        sourceFile: source,
        category: category,
        fileName: picked.name,
        mimeType: _mimeType(picked.extension),
      );

      final booking = Booking(
        id: _storage.newId(),
        tripId: widget.tripId,
        type: _typeForCategory(category),
        title: _titleFromFile(picked.name),
        fileName: localDocument.fileName,
        localPath: localDocument.localPath,
        notes: 'Uploaded locally for offline access.',
      );

      await _sync.saveModel(
        model: booking,
        entity: 'bookings',
        localSave: () => _storage.saveBooking(booking),
      );

      await _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Booking document added and saved locally.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  Future<String?> _chooseCategory() async {
    return showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Document type'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Flight'),
            child: const Text('Flight'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Hotel'),
            child: const Text('Hotel'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Activity'),
            child: const Text('Activity'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Other'),
            child: const Text('Other'),
          ),
        ],
      ),
    );
  }

  String _typeForCategory(String category) {
    return category.toLowerCase();
  }

  String _titleFromFile(String name) {
    final dot = name.lastIndexOf('.');

    final base = dot > 0
        ? name.substring(0, dot)
        : name;

    return base
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .trim();
  }

  String _mimeType(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'pdf':
        return 'application/pdf';

      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';

      case 'png':
        return 'image/png';

      case 'webp':
        return 'image/webp';

      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _openBooking(Booking booking) async {
    if (booking.localPath.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This booking has no local document.',
            ),
          ),
        );
      }

      return;
    }

    final file = File(booking.localPath);

    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The local document is no longer available.',
            ),
          ),
        );
      }

      return;
    }

    await OpenFilex.open(file.path);
  }

  Future<void> _removeBooking(Booking booking) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Delete booking document?',
        ),
        content: Text(
          'Delete ${booking.title} from this trip? '
          'The local file will also be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: TravelMateColors.coral600,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await _sync.deleteModel(
      entity: 'bookings',
      tripId: booking.tripId,
      entityId: booking.id,
      localDelete: () async {
        await _storage.deleteBooking(booking.id);

        final docs = await _storage.getLocalFiles(
          widget.tripId,
        );

        for (final doc
            in docs.where((d) => d.localPath == booking.localPath)) {
          await _storage.deleteLocalFile(doc.id);
        }
      },
    );

    await _load();
  }

  String _fileSize(String path) {
    return 'Local file';
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleBookings;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : IconButton(
                onPressed: widget.onBack,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                ),
              ),

        title: const _BookingBrandTitle(),

        // Important for small screens.
        titleSpacing: 0,

        actions: [
          _OnlineBadge(
            online: _online,
          ),

          const SizedBox(width: 8),

          const CircleAvatar(
            radius: 17,
            backgroundColor: TravelMateColors.navy900,
            child: Text(
              'PS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(width: 10),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            24,
            20,
            40,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1240,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: widget.onBack,
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        'Back to trip',
                      ),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Booking folder',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      TravelMateColors.textPrimary,
                                ),
                              ),

                              SizedBox(height: 6),

                              Text(
                                'Every confirmation and voucher '
                                'for this trip, in one place.',
                                style: TextStyle(
                                  color:
                                      TravelMateColors.textSecondary,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),

                        FilledButton.icon(
                          onPressed: _uploading
                              ? null
                              : _uploadDocument,
                          icon: _uploading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.upload_rounded,
                                ),
                          label: Text(
                            _uploading
                                ? 'Uploading...'
                                : 'Upload document',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                TravelMateColors.coral500,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    LayoutBuilder(
                      builder: (context, c) {
                        return Row(
                          children: [
                            Expanded(
                              child: TextField(
                                onChanged: (value) {
                                  setState(() {
                                    _query = value;
                                  });
                                },
                                decoration:
                                    const InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                  ),
                                  hintText:
                                      'Search bookings...',
                                ),
                              ),
                            ),

                            if (c.maxWidth > 600) ...[
                              const SizedBox(width: 10),

                              OutlinedButton.icon(
                                onPressed:
                                    _showFilterInfo,
                                icon: const Icon(
                                  Icons.tune_rounded,
                                ),
                                label: const Text(
                                  'Filter',
                                ),
                              ),

                              const SizedBox(width: 10),

                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _bookings.sort(
                                      (a, b) =>
                                          (b.bookingDate ??
                                                  b.createdAt)
                                              .compareTo(
                                        a.bookingDate ??
                                            a.createdAt,
                                      ),
                                    );
                                  });
                                },
                                icon: const Icon(
                                  Icons.swap_vert_rounded,
                                ),
                                label: const Text(
                                  'Sort',
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _tabs()
                            .map(_tabButton)
                            .toList(),
                      ),
                    ),

                    const SizedBox(height: 18),

                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (visible.isEmpty)
                      _emptyState()
                    else
                      ...visible.map(
                        (booking) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: 12,
                          ),
                          child: _BookingCard(
                            booking: booking,
                            onOpen: () =>
                                _openBooking(booking),
                            onDelete: () =>
                                _removeBooking(booking),
                            fileSize: _fileSize(
                              booking.localPath,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_BookingTab> _tabs() {
    int count(String key) {
      return _bookings.where(
        (b) =>
            key == 'all' ||
            _normaliseType(b.type) == key,
      ).length;
    }

    return [
      _BookingTab(
        'all',
        'All',
        count('all'),
      ),
      _BookingTab(
        'flights',
        'Flights',
        count('flights'),
      ),
      _BookingTab(
        'hotels',
        'Hotels',
        count('hotels'),
      ),
      _BookingTab(
        'activities',
        'Activities',
        count('activities'),
      ),
      _BookingTab(
        'other',
        'Other',
        count('other'),
      ),
    ];
  }

  Widget _tabButton(_BookingTab tab) {
    return Padding(
      padding: const EdgeInsets.only(
        right: 8,
      ),
      child: ChoiceChip(
        label: Text(
          '${tab.label} (${tab.count})',
        ),
        selected: _tab == tab.key,
        onSelected: (_) {
          setState(() {
            _tab = tab.key;
          });
        },
        selectedColor: TravelMateColors.navy900,
        labelStyle: TextStyle(
          color: _tab == tab.key
              ? Colors.white
              : TravelMateColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(
          color: _tab == tab.key
              ? TravelMateColors.navy900
              : TravelMateColors.border,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: const [
            Icon(
              Icons.folder_open_rounded,
              size: 50,
              color: TravelMateColors.textMuted,
            ),

            SizedBox(height: 12),

            Text(
              'No booking documents found',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),

            SizedBox(height: 5),

            Text(
              'Upload a confirmation, voucher or ticket '
              'to keep it available offline.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Use the booking tabs to filter by category.',
        ),
      ),
    );
  }
}

class _BookingTab {
  const _BookingTab(
    this.key,
    this.label,
    this.count,
  );

  final String key;
  final String label;
  final int count;
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.onOpen,
    required this.onDelete,
    required this.fileSize,
  });

  final Booking booking;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final String fileSize;

  @override
  Widget build(BuildContext context) {
    final type = booking.type.toLowerCase();

    final icon = type.contains('flight')
        ? Icons.flight_rounded
        : type.contains('hotel')
            ? Icons.bed_rounded
            : type.contains('activity')
                ? Icons.local_activity_rounded
                : Icons.directions_car_rounded;

    final bg = type.contains('flight')
        ? TravelMateColors.backgroundAlt
        : type.contains('hotel')
            ? TravelMateColors.teal100
            : type.contains('activity')
                ? TravelMateColors.coral100
                : TravelMateColors.warningBackground;

    final fg = type.contains('flight')
        ? TravelMateColors.navy800
        : type.contains('hotel')
            ? TravelMateColors.teal600
            : type.contains('activity')
                ? TravelMateColors.coral600
                : TravelMateColors.warning;

    final date = booking.bookingDate;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, c) {
            final compact = c.maxWidth < 620;

            final leading = Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: fg,
              ),
            );

            final details = Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment:
                      WrapCrossAlignment.center,
                  children: [
                    Text(
                      booking.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color:
                            TravelMateColors.textPrimary,
                      ),
                    ),
                    _StatusChip(
                      status: booking.notes
                              .toLowerCase()
                              .contains('pending')
                          ? 'Pending'
                          : 'Confirmed',
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                Text(
                  '${booking.referenceNumber.isEmpty ? 'Booking' : booking.referenceNumber}'
                  '${date == null ? '' : ' · ${_date(date)}'}',
                  style: const TextStyle(
                    fontSize: 13,
                    color:
                        TravelMateColors.textSecondary,
                  ),
                ),

                if (booking.fileName.isNotEmpty) ...[
                  const SizedBox(height: 4),

                  Text(
                    booking.fileName,
                    style: const TextStyle(
                      fontSize: 12,
                      color:
                          TravelMateColors.textMuted,
                    ),
                  ),
                ],
              ],
            );

            if (compact) {
              return Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  leading,

                  const SizedBox(width: 12),

                  Expanded(
                    child: details,
                  ),

                  Column(
                    children: [
                      IconButton(
                        onPressed: onOpen,
                        icon: const Icon(
                          Icons.visibility_outlined,
                        ),
                      ),

                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                leading,

                const SizedBox(width: 14),

                Expanded(
                  child: details,
                ),

                Text(
                  fileSize,
                  style: const TextStyle(
                    fontSize: 12,
                    color:
                        TravelMateColors.textMuted,
                  ),
                ),

                const SizedBox(width: 10),

                IconButton(
                  onPressed: onOpen,
                  tooltip: 'View',
                  icon: const Icon(
                    Icons.visibility_outlined,
                  ),
                ),

                IconButton(
                  onPressed: onOpen,
                  tooltip: 'Open',
                  icon: const Icon(
                    Icons.download_rounded,
                  ),
                ),

                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Delete',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _date(DateTime date) {
    const months = [
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

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final pending =
        status.toLowerCase() == 'pending';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: pending
            ? TravelMateColors.warningBackground
            : TravelMateColors.successBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: pending
              ? TravelMateColors.warning
              : TravelMateColors.success,
        ),
      ),
    );
  }
}

/// Responsive TravelMate branding used in the AppBar.
///
/// On smaller phones the logo, text and spacing are reduced slightly
/// to prevent the AppBar Row from overflowing.
class _BookingBrandTitle extends StatelessWidget {
  const _BookingBrandTitle();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 390;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 32 : 34,
          height: compact ? 32 : 34,
          decoration: BoxDecoration(
            color: TravelMateColors.teal600,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.travel_explore_rounded,
            color: Colors.white,
            size: compact ? 19 : 21,
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

/// Responsive Online/Offline badge.
class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({
    required this.online,
  });

  final bool online;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 390;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: online
            ? TravelMateColors.successBackground
            : TravelMateColors.backgroundAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 7,
            color: online
                ? TravelMateColors.success
                : TravelMateColors.textMuted,
          ),

          const SizedBox(width: 5),

          Text(
            online ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: online
                  ? TravelMateColors.success
                  : TravelMateColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}