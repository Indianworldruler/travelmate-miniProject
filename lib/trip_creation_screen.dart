import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'app_theme.dart';
import 'models.dart';
import 'storage_service.dart';
import 'sync_service.dart';

/// Create Trip screen based on the supplied TravelMate HTML screen.
///
/// The form is functional: the trip is saved to SQLite immediately and queued
/// for Firebase synchronisation. Cover images are optional; decorative preview
/// imagery continues to come from the network as in the original design.
class TripCreationScreen extends StatefulWidget {
  final Trip? initialTrip;
  final ValueChanged<Trip>? onCreated;
  final VoidCallback? onCancel;

  const TripCreationScreen({
    super.key,
    this.initialTrip,
    this.onCreated,
    this.onCancel,
  });

  @override
  State<TripCreationScreen> createState() => _TripCreationScreenState();
}

class _TripCreationScreenState extends State<TripCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _destinationController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String _travelType = 'Leisure';
  int _travellers = 3;
  bool _saving = false;

  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();

    final trip = widget.initialTrip;
    if (trip != null) {
      _nameController.text = trip.title;
      _destinationController.text = trip.destination;
      _descriptionController.text = trip.description;
      _startDate = trip.startDate;
      _endDate = trip.endDate;
      _travelType = _capitalise(trip.travelType);
      _travellers = trip.travellerCount < 1 ? 1 : trip.travellerCount;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _destinationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _capitalise(String value) {
    if (value.isEmpty) return 'Leisure';
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = start
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: start ? 'Select start date' : 'Select end date',
    );

    if (picked == null || !mounted) return;

    setState(() {
      if (start) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
        if (_startDate != null && picked.isBefore(_startDate!)) {
          _startDate = picked;
        }
      }
    });
  }

  Future<void> _createTrip() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!)) {
      _showMessage('End date cannot be before the start date.');
      return;
    }

    setState(() => _saving = true);

    try {
      final now = DateTime.now();
      final old = widget.initialTrip;

      final trip = Trip(
        id: old?.id ?? _uuid.v4(),
        title: _nameController.text.trim(),
        destination: _destinationController.text.trim(),
        description: _descriptionController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        coverImageUrl: old?.coverImageUrl,
        travelType: _travelType.toLowerCase(),
        travellerCount: _travellers,
        ownerId: old?.ownerId ?? 'local-user',
        status: old?.status ?? 'upcoming',
        createdAt: old?.createdAt ?? now,
        updatedAt: now,
      );

      await SyncService.instance.saveModel(
        model: trip,
        entity: 'trip',
        localSave: () => StorageService.instance.saveTrip(trip),
      );

      if (!mounted) return;

      widget.onCreated?.call(trip);

      if (widget.onCreated == null) {
        Navigator.of(context).pop(trip);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Trip could not be saved. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Choose date';
    return DateFormat('dd MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialTrip != null;

    return Scaffold(
      appBar: AppBar(
        title: const _Brand(),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _saving
              ? null
              : () {
                  if (widget.onCancel != null) {
                    widget.onCancel!();
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              wide ? 32 : 16,
              24,
              wide ? 32 : 16,
              40,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PageHeading(
                      editing: editing,
                      onBack: () {
                        if (widget.onCancel != null) {
                          widget.onCancel!();
                        } else {
                          Navigator.of(context).maybePop();
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildForm()),
                              const SizedBox(width: 24),
                              SizedBox(
                                width: 360,
                                child: _buildPreview(),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _buildForm(),
                              const SizedBox(height: 20),
                              _buildPreview(),
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

  Widget _buildForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _Field(
                label: 'Trip name',
                controller: _nameController,
                hint: 'e.g. Goa Escape',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a trip name';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              _Field(
                label: 'Destination',
                controller: _destinationController,
                hint: 'Where to?',
                prefixIcon: Icons.location_on_outlined,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a destination';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Start date',
                      value: _formatDate(_startDate),
                      onTap: () => _pickDate(start: true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DateField(
                      label: 'End date',
                      value: _formatDate(_endDate),
                      onTap: () => _pickDate(start: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _Field(
                label: 'Trip description',
                controller: _descriptionController,
                hint: "What's this trip about?",
                maxLines: 4,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 4),
              _SectionLabel(text: 'Cover image'),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 25,
                  horizontal: 18,
                ),
                decoration: BoxDecoration(
                  color: TravelMateColors.backgroundAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: TravelMateColors.border,
                    width: 1.3,
                  ),
                ),
                child: const Column(
                  children: [
                    _IconBox(
                      icon: Icons.image_outlined,
                      teal: true,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Online preview image',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Your trip can use an online cover image.',
                      style: TextStyle(
                        color: TravelMateColors.textMuted,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _SectionLabel(text: 'Travel type'),
              const SizedBox(height: 8),
              _TravelTypeSelector(
                value: _travelType,
                onChanged: (value) => setState(() => _travelType = value),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: _SectionLabel(text: 'Number of travellers'),
              ),
              const SizedBox(height: 8),
              _Stepper(
                value: _travellers,
                onChanged: (value) => setState(() => _travellers = value),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _createTrip,
                  style: FilledButton.styleFrom(
                    backgroundColor: TravelMateColors.coral500,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    _saving
                        ? 'Saving trip...'
                        : widget.initialTrip == null
                            ? 'Create trip'
                            : 'Save changes',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final title = _nameController.text.trim().isEmpty
        ? 'Your trip'
        : _nameController.text.trim();

    final destination = _destinationController.text.trim().isEmpty
        ? 'Add a destination'
        : _destinationController.text.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 190,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  _previewImage(destination),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: TravelMateColors.navy800,
                    child: const Icon(
                      Icons.landscape_rounded,
                      size: 54,
                      color: Colors.white70,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        TravelMateColors.navy900.withValues(alpha: .82),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        destination,
                        style: const TextStyle(
                          color: Color(0xE6FFFFFF),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PreviewChip(
                      icon: Icons.calendar_today_rounded,
                      text: _datePreview(),
                      teal: true,
                    ),
                    _PreviewChip(
                      icon: Icons.people_outline_rounded,
                      text: '$_travellers traveller${_travellers == 1 ? '' : 's'}',
                      teal: false,
                    ),
                  ],
                ),
                const Divider(height: 28),
                Text(
                  _descriptionController.text.trim().isEmpty
                      ? 'Add a short description to give your trip some character.'
                      : _descriptionController.text.trim(),
                  style: const TextStyle(
                    color: TravelMateColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This preview updates as you fill in the form.',
                  style: const TextStyle(
                    color: TravelMateColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _datePreview() {
    if (_startDate == null && _endDate == null) return 'Dates not set';
    if (_startDate != null && _endDate != null) {
      return '${DateFormat('dd MMM').format(_startDate!)} – '
          '${DateFormat('dd MMM').format(_endDate!)}';
    }
    return DateFormat('dd MMM yyyy').format(_startDate ?? _endDate!);
  }

  String _previewImage(String destination) {
    final lower = destination.toLowerCase();
    if (lower.contains('goa')) {
      return 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?auto=format&fit=crop&w=800&q=80';
    }
    if (lower.contains('rajasthan') || lower.contains('jaipur')) {
      return 'https://images.unsplash.com/photo-1477587458883-47145ed94245?auto=format&fit=crop&w=800&q=80';
    }
    if (lower.contains('kerala') || lower.contains('kochi')) {
      return 'https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?auto=format&fit=crop&w=800&q=80';
    }
    if (lower.contains('manali')) {
      return 'https://images.unsplash.com/photo-1626621341517-bbf3d9990a23?auto=format&fit=crop&w=800&q=80';
    }
    return 'https://images.unsplash.com/photo-1500534623283-312aade485b7?auto=format&fit=crop&w=800&q=80';
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

class _PageHeading extends StatelessWidget {
  final bool editing;
  final VoidCallback onBack;

  const _PageHeading({
    required this.editing,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_rounded,
                  size: 16,
                  color: TravelMateColors.textSecondary,
                ),
                SizedBox(width: 5),
                Text(
                  'My trips',
                  style: TextStyle(
                    color: TravelMateColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          editing ? 'Edit trip' : 'Create a new trip',
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -.6,
            color: TravelMateColors.navy900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          editing
              ? 'Update the basics of your trip.'
              : 'Set the basics — you can fill in the itinerary once your trip is created.',
          style: const TextStyle(
            color: TravelMateColors.textSecondary,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData? prefixIcon;
  final int maxLines;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    this.prefixIcon,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: prefixIcon == null
              ? null
              : Icon(
                  prefixIcon,
                  size: 18,
                ),
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(
              Icons.calendar_today_rounded,
              size: 17,
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: value == 'Choose date'
                  ? TravelMateColors.textMuted
                  : TravelMateColors.textPrimary,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: TravelMateColors.textPrimary,
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final bool teal;

  const _IconBox({
    required this.icon,
    required this.teal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: teal
            ? TravelMateColors.teal100
            : TravelMateColors.backgroundAlt,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        icon,
        color: teal
            ? TravelMateColors.teal600
            : TravelMateColors.navy800,
        size: 20,
      ),
    );
  }
}

class _TravelTypeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _TravelTypeSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const types = [
      ('Leisure', Icons.beach_access_rounded),
      ('Business', Icons.business_center_outlined),
      ('Adventure', Icons.terrain_rounded),
      ('Family', Icons.groups_rounded),
      ('Road trip', Icons.route_rounded),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((type) {
        final selected = type.$1 == value;
        return ChoiceChip(
          selected: selected,
          avatar: Icon(
            type.$2,
            size: 16,
            color: selected
                ? Colors.white
                : TravelMateColors.textSecondary,
          ),
          label: Text(type.$1),
          onSelected: (_) => onChanged(type.$1),
          selectedColor: TravelMateColors.navy800,
          labelStyle: TextStyle(
            color: selected
                ? Colors.white
                : TravelMateColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        );
      }).toList(),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _Stepper({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: TravelMateColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: value > 1 ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_rounded),
              visualDensity: VisualDensity.compact,
            ),
            Container(
              width: 52,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: const BoxDecoration(
                border: Border.symmetric(
                  vertical: BorderSide(color: TravelMateColors.border),
                ),
              ),
              child: Text(
                '$value',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: TravelMateColors.navy800,
                ),
              ),
            ),
            IconButton(
              onPressed: value < 30 ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add_rounded),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool teal;

  const _PreviewChip({
    required this.icon,
    required this.text,
    required this.teal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: teal
            ? TravelMateColors.teal100
            : const Color(0xFFE7EDF4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: teal
                ? TravelMateColors.teal600
                : TravelMateColors.navy800,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: teal
                  ? TravelMateColors.teal600
                  : TravelMateColors.navy800,
            ),
          ),
        ],
      ),
    );
  }
}
