import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'models.dart';

class TripDashboardScreen extends StatelessWidget {
  final Trip trip;
  final ValueChanged<String>? onToolSelected;
  final VoidCallback? onBack;
  final VoidCallback? onEdit;

  const TripDashboardScreen({
    super.key,
    required this.trip,
    this.onToolSelected,
    this.onBack,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TravelMateColors.background,
      appBar: AppBar(
        title: const _Brand(),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: onBack ??
              () {
                Navigator.of(context).maybePop();
              },
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
        ),
        actions: [
          if (onEdit != null)
            IconButton(
              tooltip: 'Edit trip',
              onPressed: onEdit,
              icon: const Icon(
                Icons.edit_outlined,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool wide = constraints.maxWidth >= 1000;

          final double horizontalPadding =
              constraints.maxWidth >= 900 ? 32 : 16;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              20,
              horizontalPadding,
              40,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1180,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _BackLink(
                      onBack: onBack,
                    ),
                    const SizedBox(height: 14),
                    _HeroCard(
                      trip: trip,
                      onEdit: onEdit,
                    ),
                    const SizedBox(height: 20),
                    _Stats(
                      trip: trip,
                    ),
                    const SizedBox(height: 24),
                    if (wide)
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _Tools(
                              onSelected:
                                  onToolSelected,
                            ),
                          ),
                          const SizedBox(width: 20),
                          SizedBox(
                            width: 320,
                            child: _SideWidget(
                              trip: trip,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _Tools(
                            onSelected:
                                onToolSelected,
                          ),
                          const SizedBox(height: 20),
                          _SideWidget(
                            trip: trip,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ================================================================
// BRAND
// ================================================================

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
            borderRadius:
                BorderRadius.circular(10),
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
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: TravelMateColors.navy800,
          ),
        ),
      ],
    );
  }
}

// ================================================================
// BACK LINK
// ================================================================

class _BackLink extends StatelessWidget {
  final VoidCallback? onBack;

  const _BackLink({
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onBack ??
          () {
            Navigator.of(context).maybePop();
          },
      borderRadius: BorderRadius.circular(8),
      child: const Padding(
        padding: EdgeInsets.symmetric(
          vertical: 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back_rounded,
              size: 16,
              color:
                  TravelMateColors.textSecondary,
            ),
            SizedBox(width: 5),
            Text(
              'My trips',
              style: TextStyle(
                color:
                    TravelMateColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// HERO
// ================================================================

class _HeroCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback? onEdit;

  const _HeroCard({
    required this.trip,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 270,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              trip.coverImageUrl ??
                  _fallbackImage(
                    trip.destination,
                  ),
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) {
                return Container(
                  decoration:
                      const BoxDecoration(
                    gradient:
                        LinearGradient(
                      colors: [
                        TravelMateColors.navy900,
                        TravelMateColors.teal600,
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.landscape_rounded,
                    color: Colors.white70,
                    size: 60,
                  ),
                );
              },
            ),

            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    TravelMateColors.navy900
                        .withValues(alpha: 0.05),
                    TravelMateColors.navy900
                        .withValues(alpha: 0.82),
                  ],
                ),
              ),
            ),

            Positioned(
              left: 24,
              right: 24,
              bottom: 22,
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _StatusChip(
                          trip: trip,
                        ),
                        const SizedBox(height: 9),
                        Text(
                          trip.title.isEmpty
                              ? 'Untitled trip'
                              : trip.title,
                          style:
                              const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight:
                                FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                trip.destination
                                        .isEmpty
                                    ? 'Destination not set'
                                    : trip.destination,
                                style:
                                    const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (onEdit != null)
                    FilledButton.icon(
                      onPressed: onEdit,
                      style:
                          FilledButton.styleFrom(
                        backgroundColor:
                            Colors.white,
                        foregroundColor:
                            TravelMateColors.navy800,
                      ),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 17,
                      ),
                      label: const Text(
                        'Edit',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fallbackImage(
    String destination,
  ) {
    final String lower =
        destination.toLowerCase();

    if (lower.contains('goa')) {
      return 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?auto=format&fit=crop&w=1000&q=80';
    }

    if (lower.contains('rajasthan') ||
        lower.contains('jaipur')) {
      return 'https://images.unsplash.com/photo-1477587458883-47145ed94245?auto=format&fit=crop&w=1000&q=80';
    }

    if (lower.contains('kerala') ||
        lower.contains('kochi')) {
      return 'https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?auto=format&fit=crop&w=1000&q=80';
    }

    if (lower.contains('manali')) {
      return 'https://images.unsplash.com/photo-1626621341517-bbf3d9990a23?auto=format&fit=crop&w=1000&q=80';
    }

    return 'https://images.unsplash.com/photo-1500534623283-312aade485b7?auto=format&fit=crop&w=1000&q=80';
  }
}

// ================================================================
// STATUS
// ================================================================

class _StatusChip extends StatelessWidget {
  final Trip trip;

  const _StatusChip({
    required this.trip,
  });

  @override
  Widget build(BuildContext context) {
    final String status = _status();
    final bool ongoing = status == 'ongoing';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: ongoing
            ? TravelMateColors.warningBackground
            : TravelMateColors.teal100,
        borderRadius:
            BorderRadius.circular(999),
      ),
      child: Text(
        status[0].toUpperCase() +
            status.substring(1),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: ongoing
              ? TravelMateColors.warning
              : TravelMateColors.teal600,
        ),
      ),
    );
  }

  String _status() {
    final DateTime now = DateTime.now();

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

// ================================================================
// STATS
// ================================================================

class _Stats extends StatelessWidget {
  final Trip trip;

  const _Stats({
    required this.trip,
  });

  @override
  Widget build(BuildContext context) {
    final List<_StatData> cards = [
      _StatData(
        icon: Icons.calendar_month_rounded,
        label: 'Trip dates',
        value: _dates(),
        tone: _Tone.teal,
      ),
      _StatData(
        icon: Icons.people_alt_outlined,
        label: 'Travellers',
        value: '${trip.travellerCount}',
        tone: _Tone.navy,
      ),
      _StatData(
        icon: Icons.event_note_rounded,
        label: 'Itinerary',
        value: 'Ready to plan',
        tone: _Tone.coral,
      ),
      _StatData(
        icon: Icons.cloud_done_outlined,
        label: 'Sync',
        value: 'Local-first',
        tone: _Tone.success,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns =
            constraints.maxWidth >= 850 ? 4 : 2;

        const double gap = 12;

        final double width =
            (constraints.maxWidth -
                    ((columns - 1) * gap)) /
                columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards.map(
            (card) {
              return SizedBox(
                width: width,
                child: _StatCard(
                  data: card,
                ),
              );
            },
          ).toList(),
        );
      },
    );
  }

  String _dates() {
    if (trip.startDate == null &&
        trip.endDate == null) {
      return 'Not set';
    }

    if (trip.startDate != null &&
        trip.endDate != null) {
      final int days =
          trip.endDate!
                  .difference(
                    trip.startDate!,
                  )
                  .inDays +
              1;

      return '$days day${days == 1 ? '' : 's'}';
    }

    return '1 date';
  }
}

enum _Tone {
  teal,
  navy,
  coral,
  success,
}

class _StatData {
  final IconData icon;
  final String label;
  final String value;
  final _Tone tone;

  const _StatData({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
  });
}

// ================================================================
// STAT CARD
// ================================================================

class _StatCard extends StatelessWidget {
  final _StatData data;

  const _StatCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final Color background;

    switch (data.tone) {
      case _Tone.teal:
        background =
            TravelMateColors.teal100;
        break;
      case _Tone.navy:
        background =
            const Color(0xFFE7EDF4);
        break;
      case _Tone.coral:
        background =
            TravelMateColors.coral100;
        break;
      case _Tone.success:
        background =
            TravelMateColors.successBackground;
        break;
    }

    final Color foreground;

    switch (data.tone) {
      case _Tone.teal:
        foreground =
            TravelMateColors.teal600;
        break;
      case _Tone.navy:
        foreground =
            TravelMateColors.navy800;
        break;
      case _Tone.coral:
        foreground =
            TravelMateColors.coral600;
        break;
      case _Tone.success:
        foreground =
            TravelMateColors.success;
        break;
    }

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: background,
                borderRadius:
                    BorderRadius.circular(11),
              ),
              child: Icon(
                data.icon,
                color: foreground,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style:
                        const TextStyle(
                      color:
                          TravelMateColors.textMuted,
                      fontSize: 11.5,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.value,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color:
                          TravelMateColors.navy900,
                      fontWeight:
                          FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// TOOLS
// ================================================================

class _Tools extends StatelessWidget {
  final ValueChanged<String>? onSelected;

  const _Tools({
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const List<_ToolData> tools = [
      _ToolData(
        key: 'itinerary',
        title: 'Day-wise itinerary',
        description:
            'Build and organise each day of your trip.',
        icon: Icons.view_timeline_outlined,
        tone: _Tone.teal,
      ),
      _ToolData(
        key: 'bookings',
        title: 'Booking folder',
        description:
            'Keep booking information in one place.',
        icon: Icons.folder_copy_outlined,
        tone: _Tone.coral,
      ),
      _ToolData(
        key: 'offline',
        title: 'Offline storage',
        description:
            'Access your saved trip information offline.',
        icon: Icons.cloud_off_outlined,
        tone: _Tone.success,
      ),
      _ToolData(
        key: 'maps',
        title: 'Google Maps',
        description:
            'Save useful places and open them in Maps.',
        icon: Icons.map_outlined,
        tone: _Tone.teal,
      ),
      _ToolData(
        key: 'road_trip',
        title: 'Road trip planner',
        description:
            'Plan stops and the route between them.',
        icon: Icons.alt_route_rounded,
        tone: _Tone.coral,
      ),
      _ToolData(
        key: 'packing',
        title: 'Packing checklist',
        description:
            'Track everything you need to take.',
        icon: Icons.backpack_outlined,
        tone: _Tone.navy,
      ),
      _ToolData(
        key: 'todo',
        title: 'Travel to-do',
        description:
            'Keep preparation tasks under control.',
        icon: Icons.check_circle_outline_rounded,
        tone: _Tone.teal,
      ),
      _ToolData(
        key: 'notes',
        title: 'Travel notes',
        description:
            'Save ideas, reminders and useful details.',
        icon: Icons.sticky_note_2_outlined,
        tone: _Tone.coral,
      ),
      _ToolData(
        key: 'expenses',
        title: 'Expenses',
        description:
            'Track basic spending for the trip.',
        icon:
            Icons.account_balance_wallet_outlined,
        tone: _Tone.success,
      ),
    ];

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Trip tools',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color:
                    TravelMateColors.navy900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Everything you need to plan and manage this trip.',
              style: TextStyle(
                fontSize: 13,
                color:
                    TravelMateColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder:
                  (context, constraints) {
                final int columns =
                    constraints.maxWidth >= 800
                        ? 3
                        : constraints.maxWidth >= 520
                            ? 2
                            : 1;

                const double gap = 12;

                final double width =
                    (constraints.maxWidth -
                            ((columns - 1) *
                                gap)) /
                        columns;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: tools.map(
                    (tool) {
                      return SizedBox(
                        width: width,
                        child: _ToolCard(
                          data: tool,

                          // IMPORTANT:
                          // This directly reports the tap.
                          onTap: () {
                            if (onSelected !=
                                null) {
                              onSelected!(
                                tool.key,
                              );
                            }
                          },
                        ),
                      );
                    },
                  ).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// TOOL DATA
// ================================================================

class _ToolData {
  final String key;
  final String title;
  final String description;
  final IconData icon;
  final _Tone tone;

  const _ToolData({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.tone,
  });
}

// ================================================================
// TOOL CARD
// ================================================================

class _ToolCard extends StatelessWidget {
  final _ToolData data;
  final VoidCallback onTap;

  const _ToolCard({
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;

    switch (data.tone) {
      case _Tone.teal:
        background =
            TravelMateColors.teal100;
        foreground =
            TravelMateColors.teal600;
        break;

      case _Tone.navy:
        background =
            const Color(0xFFE7EDF4);
        foreground =
            TravelMateColors.navy800;
        break;

      case _Tone.coral:
        background =
            TravelMateColors.coral100;
        foreground =
            TravelMateColors.coral600;
        break;

      case _Tone.success:
        background =
            TravelMateColors.successBackground;
        foreground =
            TravelMateColors.success;
        break;
    }

    return Material(
      color: TravelMateColors.background,
      borderRadius:
          BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(14),
        child: Padding(
          padding:
              const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(
                  color: background,
                  borderRadius:
                      BorderRadius.circular(11),
                ),
                child: Icon(
                  data.icon,
                  size: 19,
                  color: foreground,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style:
                          const TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            TravelMateColors
                                .textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      data.description,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color:
                            TravelMateColors
                                .textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: foreground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// SIDE WIDGET
// ================================================================

class _SideWidget extends StatelessWidget {
  final Trip trip;

  const _SideWidget({
    required this.trip,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasDates =
        trip.startDate != null &&
            trip.endDate != null;

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                _MiniIcon(
                  icon:
                      Icons.lightbulb_outline_rounded,
                  coral: true,
                ),
                SizedBox(width: 10),
                Text(
                  'Trip at a glance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        TravelMateColors.navy900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _GlanceRow(
              icon:
                  Icons.location_on_outlined,
              label: 'Destination',
              value:
                  trip.destination.isEmpty
                      ? 'Not set'
                      : trip.destination,
            ),
            _GlanceRow(
              icon:
                  Icons.people_outline_rounded,
              label: 'Travellers',
              value:
                  '${trip.travellerCount}',
            ),
            _GlanceRow(
              icon:
                  Icons.category_outlined,
              label: 'Travel type',
              value:
                  trip.travelType.isEmpty
                      ? 'Leisure'
                      : trip.travelType,
            ),
            _GlanceRow(
              icon:
                  Icons.date_range_outlined,
              label: 'Dates',
              value: hasDates
                  ? 'Dates ready'
                  : 'Add dates',
            ),
            const Divider(height: 28),
            Container(
              padding:
                  const EdgeInsets.all(14),
              decoration:
                  BoxDecoration(
                color:
                    TravelMateColors.teal100,
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.cloud_done_outlined,
                    size: 19,
                    color:
                        TravelMateColors.teal600,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Your changes are saved locally first and synchronised when Firebase is available.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color:
                            TravelMateColors.teal600,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// MINI ICON
// ================================================================

class _MiniIcon extends StatelessWidget {
  final IconData icon;
  final bool coral;

  const _MiniIcon({
    required this.icon,
    required this.coral,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration:
          BoxDecoration(
        color: coral
            ? TravelMateColors.coral100
            : TravelMateColors.teal100,
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 19,
        color: coral
            ? TravelMateColors.coral600
            : TravelMateColors.teal600,
      ),
    );
  }
}

// ================================================================
// GLANCE ROW
// ================================================================

class _GlanceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _GlanceRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 13,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color:
                TravelMateColors.textMuted,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style:
                  const TextStyle(
                fontSize: 12.5,
                color:
                    TravelMateColors
                        .textSecondary,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign:
                  TextAlign.right,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontSize: 12.5,
                fontWeight:
                    FontWeight.w700,
                color:
                    TravelMateColors
                        .textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}