import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_theme.dart';
import 'models.dart';
import 'storage_service.dart';
import 'sync_service.dart';

class GoogleMapsScreen extends StatefulWidget {
  const GoogleMapsScreen({
    super.key,
    required this.tripId,
  });

  final String tripId;

  @override
  State<GoogleMapsScreen> createState() => _GoogleMapsScreenState();
}

class _GoogleMapsScreenState extends State<GoogleMapsScreen> {
  final StorageService _storage = StorageService.instance;
  final SyncService _sync = SyncService.instance;

  final TextEditingController _searchController =
      TextEditingController();

  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController _addressController =
      TextEditingController();

  final TextEditingController _relatedController =
      TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();

  StreamSubscription<SyncStatus>? _syncSubscription;

  SyncStatus _status = const SyncStatus(
    online: false,
    syncing: false,
    pendingItems: 0,
  );

  List<SavedLocation> _locations = [];

  String _query = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _status = _sync.status;

    _syncSubscription = _sync.statusStream.listen((value) {
      if (!mounted) return;

      setState(() {
        _status = value;
      });
    });

    _searchController.addListener(_onSearchChanged);

    _load();
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();

    _searchController.removeListener(_onSearchChanged);

    _searchController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _relatedController.dispose();
    _nameFocusNode.dispose();

    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;

    setState(() {
      _query =
          _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _load() async {
    try {
      await _storage.initialise();

      final locations =
          await _storage.getLocations(widget.tripId);

      if (!mounted) return;

      setState(() {
        _locations = locations;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  List<SavedLocation> get _filtered {
    if (_query.isEmpty) {
      return _locations;
    }

    return _locations.where((location) {
      final text =
          '${location.name} '
          '${location.address} '
          '${location.category}'
              .toLowerCase();

      return text.contains(_query);
    }).toList();
  }

  String _mapsUrl(SavedLocation location) {
    final savedUrl =
        location.mapsUrl?.trim();

    if (savedUrl != null &&
        savedUrl.isNotEmpty) {
      return savedUrl;
    }

    final query = Uri.encodeComponent(
      '${location.name}, ${location.address}'
          .trim(),
    );

    return 'https://www.google.com/maps/search/'
        '?api=1&query=$query';
  }

  String _createMapsUrl(
    String name,
    String address,
  ) {
    final query = Uri.encodeComponent(
      '$name, $address'.trim(),
    );

    return 'https://www.google.com/maps/search/'
        '?api=1&query=$query';
  }

  Future<void> _openMaps(
    SavedLocation location,
  ) async {
    final uri = Uri.tryParse(
      _mapsUrl(location),
    );

    if (uri == null) {
      if (mounted) {
        _message(
          'Invalid Google Maps link.',
        );
      }
      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        _message(
          'Could not open Google Maps.',
        );
      }
    } catch (_) {
      if (mounted) {
        _message(
          'Could not open Google Maps.',
        );
      }
    }
  }

  Future<void> _saveLocation() async {
    if (_saving) return;

    final name =
        _nameController.text.trim();

    final address =
        _addressController.text.trim();

    final related =
        _relatedController.text.trim();

    if (name.isEmpty) {
      _message(
        'Enter a location name first.',
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _saving = true;
    });

    try {
      final id = _storage.newId();

      final location = SavedLocation(
        id: id,
        tripId: widget.tripId,
        name: name,
        address: address,
        mapsUrl: _createMapsUrl(
          name,
          address,
        ),
        category:
            related.isEmpty ? 'Place' : related,
      );

      await _sync.saveModel(
        model: location,
        entity: 'location',
        localSave: () =>
            _storage.saveLocation(location),
      );

      if (!mounted) return;

      _nameController.clear();
      _addressController.clear();
      _relatedController.clear();

      await _load();

      if (!mounted) return;

      _message(
        'Location saved for this trip.',
      );
    } catch (_) {
      if (mounted) {
        _message(
          'Could not save the location.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _deleteLocation(
    SavedLocation location,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Remove location?',
          ),
          content: Text(
            'Remove ${location.name} '
            'from this trip?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: const Text(
                'Remove',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _sync.deleteModel(
        entity: 'location',
        tripId: widget.tripId,
        entityId: location.id,
        localDelete: () =>
            _storage.deleteLocation(
          location.id,
        ),
      );

      await _load();

      if (mounted) {
        _message(
          'Location removed.',
        );
      }
    } catch (_) {
      if (mounted) {
        _message(
          'Could not remove the location.',
        );
      }
    }
  }

  void _focusAddLocation() {
    _nameFocusNode.requestFocus();
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const _BrandTitle(),

        // Removes unnecessary AppBar title spacing.
        titleSpacing: 0,

        actions: [
          _ConnectionChip(
            status: _status,
          ),

          const SizedBox(width: 8),

          const _ProfileAvatar(),

          const SizedBox(width: 10),
        ],
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
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  24,
                  20,
                  40,
                ),
                children: [
                  _Header(
                    onAdd: _focusAddLocation,
                  ),

                  const SizedBox(height: 20),

                  LayoutBuilder(
                    builder: (
                      context,
                      constraints,
                    ) {
                      final wide =
                          constraints.maxWidth >= 900;

                      final list = _LocationList(
                        controller:
                            _searchController,
                        locations: _filtered,
                        onOpen: _openMaps,
                        onDelete:
                            _deleteLocation,
                      );

                      final form =
                          _AddLocationCard(
                        nameController:
                            _nameController,
                        addressController:
                            _addressController,
                        relatedController:
                            _relatedController,
                        nameFocusNode:
                            _nameFocusNode,
                        saving: _saving,
                        onSave: _saveLocation,
                      );

                      if (wide) {
                        return Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: list,
                            ),

                            const SizedBox(
                              width: 20,
                            ),

                            SizedBox(
                              width: 380,
                              child: form,
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          list,

                          const SizedBox(
                            height: 20,
                          ),

                          form,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

/// Responsive TravelMate AppBar branding.
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
            gradient:
                const LinearGradient(
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
          overflow:
              TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize:
                compact ? 18 : 20,
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
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Responsive online/offline chip.
class _ConnectionChip
    extends StatelessWidget {
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
            ? TravelMateColors
                .successBackground
            : TravelMateColors
                .warningBackground,
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
              fontSize:
                  compact ? 10 : 11,
              fontWeight:
                  FontWeight.w800,
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

class _Header extends StatelessWidget {
  const _Header({
    required this.onAdd,
  });

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          '‹  Goa Escape',
          style: TextStyle(
            color:
                TravelMateColors
                    .textSecondary,
            fontWeight:
                FontWeight.w600,
          ),
        ),

        const SizedBox(height: 14),

        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final compact =
                constraints.maxWidth < 600;

            if (compact) {
              return Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Locations & map links',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Every place on this trip, '
                    'one tap from directions.',
                    style: TextStyle(
                      color:
                          TravelMateColors
                              .textSecondary,
                    ),
                  ),

                  const SizedBox(height: 14),

                  OutlinedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(
                      Icons.add_rounded,
                    ),
                    label: const Text(
                      'Add location',
                    ),
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        'Locations & map links',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),

                      SizedBox(height: 6),

                      Text(
                        'Every place on this trip, '
                        'one tap from directions.',
                        style: TextStyle(
                          color:
                              TravelMateColors
                                  .textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                OutlinedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(
                    Icons.add_rounded,
                  ),
                  label: const Text(
                    'Add location',
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LocationList extends StatelessWidget {
  const _LocationList({
    required this.controller,
    required this.locations,
    required this.onOpen,
    required this.onDelete,
  });

  final TextEditingController controller;
  final List<SavedLocation> locations;

  final Future<void> Function(
    SavedLocation,
  ) onOpen;

  final Future<void> Function(
    SavedLocation,
  ) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            prefixIcon: Icon(
              Icons.search_rounded,
            ),
            hintText:
                'Search locations...',
          ),
        ),

        const SizedBox(height: 14),

        if (locations.isEmpty)
          const _EmptyLocations()
        else
          ...locations.map(
            (location) => Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 14,
              ),
              child: _LocationCard(
                location: location,
                onOpen: onOpen,
                onDelete: onDelete,
              ),
            ),
          ),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.location,
    required this.onOpen,
    required this.onDelete,
  });

  final SavedLocation location;

  final Future<void> Function(
    SavedLocation,
  ) onOpen;

  final Future<void> Function(
    SavedLocation,
  ) onDelete;

  @override
  Widget build(BuildContext context) {
    final icon = switch (
        location.category.toLowerCase()) {
      'sightseeing' =>
        Icons.landscape_rounded,
      'hotel' =>
        Icons.bed_rounded,
      'dinner' ||
      'food' ||
      'restaurant' =>
        Icons.restaurant_rounded,
      'shopping' =>
        Icons.shopping_bag_rounded,
      _ =>
        Icons.place_rounded,
    };

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final compact =
                constraints.maxWidth < 560;

            final locationInfo = Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration:
                      BoxDecoration(
                    color:
                        TravelMateColors
                            .teal100,
                    borderRadius:
                        BorderRadius
                            .circular(12),
                  ),
                  child: Icon(
                    icon,
                    color:
                        TravelMateColors
                            .teal600,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        location.name,
                        maxLines: 2,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),

                      if (location
                          .address
                          .isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            top: 4,
                          ),
                          child: Text(
                            location.address,
                            maxLines: 2,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              color:
                                  TravelMateColors
                                      .textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),

                      Padding(
                        padding:
                            const EdgeInsets
                                .only(
                          top: 4,
                        ),
                        child: Text(
                          location.category,
                          style:
                              const TextStyle(
                            color:
                                TravelMateColors
                                    .textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .stretch,
                children: [
                  locationInfo,

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child:
                            OutlinedButton.icon(
                          onPressed: () =>
                              onOpen(
                            location,
                          ),
                          icon: const Icon(
                            Icons
                                .open_in_new_rounded,
                            size: 17,
                          ),
                          label:
                              const Text(
                            'Open in Maps',
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      PopupMenuButton<
                          String>(
                        onSelected:
                            (value) {
                          if (value ==
                              'delete') {
                            onDelete(
                              location,
                            );
                          }
                        },
                        itemBuilder:
                            (_) =>
                                const [
                          PopupMenuItem(
                            value: 'delete',
                            child:
                                Text(
                              'Remove',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: locationInfo,
                ),

                const SizedBox(width: 8),

                OutlinedButton.icon(
                  onPressed: () =>
                      onOpen(location),
                  icon: const Icon(
                    Icons
                        .open_in_new_rounded,
                    size: 17,
                  ),
                  label: const Text(
                    'Open in Maps',
                  ),
                ),

                PopupMenuButton<String>(
                  onSelected:
                      (value) {
                    if (value ==
                        'delete') {
                      onDelete(location);
                    }
                  },
                  itemBuilder: (_) =>
                      const [
                    PopupMenuItem(
                      value: 'delete',
                      child:
                          Text('Remove'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AddLocationCard
    extends StatelessWidget {
  const _AddLocationCard({
    required this.nameController,
    required this.addressController,
    required this.relatedController,
    required this.nameFocusNode,
    required this.saving,
    required this.onSave,
  });

  final TextEditingController nameController;
  final TextEditingController addressController;
  final TextEditingController relatedController;
  final FocusNode nameFocusNode;

  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Add a location',
              style: TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(height: 18),

            const _FieldLabel(
              'Location name',
            ),

            TextField(
              controller: nameController,
              focusNode: nameFocusNode,
              textInputAction:
                  TextInputAction.next,
              decoration:
                  const InputDecoration(
                hintText:
                    'e.g. Chapora Fort',
              ),
            ),

            const SizedBox(height: 14),

            const _FieldLabel(
              'Address',
            ),

            TextField(
              controller:
                  addressController,
              textInputAction:
                  TextInputAction.next,
              decoration:
                  const InputDecoration(
                hintText:
                    'Area, city',
              ),
            ),

            const SizedBox(height: 14),

            const _FieldLabel(
              'Related to',
            ),

            TextField(
              controller:
                  relatedController,
              decoration:
                  const InputDecoration(
                hintText:
                    'e.g. Day 3 · Sightseeing',
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    saving ? null : onSave,
                icon: saving
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color:
                              Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons
                            .location_on_rounded,
                      ),
                label: Text(
                  saving
                      ? 'Saving...'
                      : 'Save location',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel
    extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 7,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight:
              FontWeight.w700,
          color:
              TravelMateColors
                  .textSecondary,
        ),
      ),
    );
  }
}

class _EmptyLocations
    extends StatelessWidget {
  const _EmptyLocations();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(28),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration:
                    BoxDecoration(
                  color:
                      TravelMateColors
                          .teal100,
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
                child: const Icon(
                  Icons.map_rounded,
                  color:
                      TravelMateColors
                          .teal600,
                  size: 28,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'No saved locations yet',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'Add a place and TravelMate '
                'will create a Google Maps '
                'link for it.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color:
                      TravelMateColors
                          .textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}