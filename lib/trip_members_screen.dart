import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'models.dart';
import 'storage_service.dart';
import 'sync_service.dart';

class TripMembersScreen extends StatefulWidget {
  const TripMembersScreen({super.key, required this.tripId, this.onBack});

  final String tripId;
  final VoidCallback? onBack;

  @override
  State<TripMembersScreen> createState() => _TripMembersScreenState();
}

class _TripMembersScreenState extends State<TripMembersScreen> {
  final _storage = StorageService.instance;
  final _sync = SyncService.instance;

  List<TripMember> _members = [];
  bool _loading = true;
  bool _online = false;
  StreamSubscription<SyncStatus>? _statusSub;
  StreamSubscription<Map<String, dynamic>>? _remoteSub;

  String get _inviteLink => 'travelmate.io/join/${widget.tripId.substring(0, widget.tripId.length < 8 ? widget.tripId.length : 8)}';

  @override
  void initState() {
    super.initState();
    _load();
    _statusSub = _sync.statusStream.listen((status) {
      if (mounted) setState(() => _online = status.online);
    });
    if (_sync.status.online) _online = true;
    _remoteSub = _sync.watchCollection(
      entity: 'members',
      tripId: widget.tripId,
      onChanged: (data) async {
        await _sync.cacheRemoteCollection(
          entity: 'members',
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
    final members = await _storage.getMembers(widget.tripId);
    if (!mounted) return;
    setState(() {
      _members = members;
      _loading = false;
    });
  }

  Future<void> _copyInvite() async {
    await Clipboard.setData(ClipboardData(text: _inviteLink));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite link copied.')),
    );
  }

  Future<void> _addMember() async {
    final result = await showDialog<_MemberDraft>(
      context: context,
      builder: (_) => const _AddMemberDialog(),
    );
    if (result == null) return;

    final member = TripMember(
      id: _storage.newId(),
      tripId: widget.tripId,
      name: result.name,
      email: result.email,
      role: result.role,
    );
    await _sync.saveModel(
      model: member,
      entity: 'members',
      localSave: () => _storage.saveMember(member),
    );
    await _load();
  }

  Future<void> _removeMember(TripMember member) async {
    if (member.role.toLowerCase() == 'owner') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The trip owner cannot be removed.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text('Remove ${member.name} from this trip?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: TravelMateColors.coral600),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _sync.deleteModel(
      entity: 'members',
      tripId: member.tripId,
      entityId: member.id,
      localDelete: () => _storage.deleteMember(member.id),
    );
    await _load();
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Color _avatarColor(int index) {
    const colors = [
      TravelMateColors.teal100,
      TravelMateColors.coral100,
      TravelMateColors.backgroundAlt,
      TravelMateColors.successBackground,
    ];
    return colors[index % colors.length];
  }

  Color _avatarTextColor(int index) {
    const colors = [
      TravelMateColors.teal600,
      TravelMateColors.coral600,
      TravelMateColors.navy800,
      TravelMateColors.success,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded)),
        title: const _BrandTitle(),
        actions: [
          _OnlineBadge(online: _online),
          const SizedBox(width: 12),
          const CircleAvatar(
            radius: 18,
            backgroundColor: TravelMateColors.navy900,
            child: Text('PS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 18),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Back to trip'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Trip members', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: TravelMateColors.textPrimary)),
                              SizedBox(height: 6),
                              Text('Manage who can view and edit this trip.', style: TextStyle(color: TravelMateColors.textSecondary, fontSize: 15)),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _addMember,
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('Add member'),
                          style: FilledButton.styleFrom(
                            backgroundColor: TravelMateColors.coral500,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final narrow = constraints.maxWidth < 650;
                            final field = Expanded(
                              child: TextField(
                                readOnly: true,
                                controller: TextEditingController(text: _inviteLink),
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.link_rounded),
                                  hintText: 'Invite link',
                                ),
                              ),
                            );
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Invite by link', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                const SizedBox(height: 12),
                                if (narrow)
                                  Column(children: [field, const SizedBox(height: 10), _copyButton()])
                                else
                                  Row(children: [field, const SizedBox(width: 12), _copyButton()]),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: _loading
                            ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                            : _members.isEmpty
                                ? _emptyMembers()
                                : Column(
                                    children: [
                                      _MemberHeader(),
                                      const Divider(height: 24),
                                      ..._members.asMap().entries.map((entry) => _MemberRow(
                                            member: entry.value,
                                            index: entry.key,
                                            initials: _initials(entry.value.name),
                                            avatarColor: _avatarColor(entry.key),
                                            avatarTextColor: _avatarTextColor(entry.key),
                                            onRemove: () => _removeMember(entry.value),
                                          )),
                                    ],
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

  Widget _copyButton() => OutlinedButton.icon(
        onPressed: _copyInvite,
        icon: const Icon(Icons.copy_rounded),
        label: const Text('Copy link'),
      );

  Widget _emptyMembers() => const Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.groups_2_rounded, size: 44, color: TravelMateColors.textMuted),
            SizedBox(height: 10),
            Text('No members yet', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Add people directly or share the invite link.', textAlign: TextAlign.center),
          ],
        ),
      );
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: TravelMateColors.teal600,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.travel_explore_rounded, color: Colors.white, size: 21),
        ),
        const SizedBox(width: 10),
        const Text('TravelMate', style: TextStyle(fontWeight: FontWeight.w800)),
      ]);
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.online});
  final bool online;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: online ? TravelMateColors.successBackground : TravelMateColors.backgroundAlt,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.circle, size: 8, color: online ? TravelMateColors.success : TravelMateColors.textMuted),
          const SizedBox(width: 6),
          Text(online ? 'Online' : 'Offline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: online ? TravelMateColors.success : TravelMateColors.textSecondary)),
        ]),
      );
}

class _MemberHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 760) return const SizedBox.shrink();
        return const Row(children: [
          SizedBox(width: 44),
          Expanded(flex: 2, child: _HeaderText('Name')),
          Expanded(flex: 2, child: _HeaderText('Email')),
          SizedBox(width: 100, child: _HeaderText('Role')),
          SizedBox(width: 110, child: _HeaderText('Joined')),
          SizedBox(width: 40),
        ]);
      });
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: const TextStyle(fontSize: 11, letterSpacing: .6, fontWeight: FontWeight.w800, color: TravelMateColors.textMuted));
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.index, required this.initials, required this.avatarColor, required this.avatarTextColor, required this.onRemove});
  final TripMember member;
  final int index;
  final String initials;
  final Color avatarColor;
  final Color avatarTextColor;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: LayoutBuilder(builder: (context, c) {
          final compact = c.maxWidth < 760;
          final avatar = CircleAvatar(radius: 22, backgroundColor: avatarColor, child: Text(initials, style: TextStyle(color: avatarTextColor, fontWeight: FontWeight.w800)));
          final identity = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(member.name, style: const TextStyle(fontWeight: FontWeight.w700, color: TravelMateColors.textPrimary)),
            if (compact) ...[
              const SizedBox(height: 3),
              Text(member.email.isEmpty ? 'No email' : member.email, style: const TextStyle(fontSize: 13, color: TravelMateColors.textSecondary)),
            ],
          ]);

          if (compact) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              avatar,
              const SizedBox(width: 12),
              Expanded(child: identity),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                _RoleChip(member.role),
                const SizedBox(height: 8),
                IconButton(onPressed: onRemove, icon: const Icon(Icons.more_vert_rounded)),
              ]),
            ]);
          }

          return Row(children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(flex: 2, child: identity),
            Expanded(flex: 2, child: Text(member.email, style: const TextStyle(fontSize: 13, color: TravelMateColors.textSecondary))),
            SizedBox(width: 100, child: _RoleChip(member.role)),
            SizedBox(width: 110, child: Text(_date(member.joinedAt), style: const TextStyle(fontSize: 13, color: TravelMateColors.textSecondary))),
            SizedBox(width: 40, child: IconButton(onPressed: onRemove, icon: const Icon(Icons.more_vert_rounded))),
          ]);
        }),
      );

  String _date(DateTime date) => '${date.day} ${_month(date.month)} ${date.year}';
  String _month(int m) => const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
}

class _RoleChip extends StatelessWidget {
  const _RoleChip(this.role);
  final String role;
  @override
  Widget build(BuildContext context) {
    final owner = role.toLowerCase() == 'owner';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: owner ? TravelMateColors.navy900 : TravelMateColors.backgroundAlt, borderRadius: BorderRadius.circular(20)),
      child: Text(owner ? 'Owner' : 'Member', style: TextStyle(color: owner ? Colors.white : TravelMateColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _MemberDraft {
  const _MemberDraft({required this.name, required this.email, required this.role});
  final String name;
  final String email;
  final String role;
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog();
  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  String _role = 'member';

  @override
  void dispose() { _name.dispose(); _email.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add trip member'),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: const [DropdownMenuItem(value: 'member', child: Text('Member')), DropdownMenuItem(value: 'editor', child: Text('Editor'))],
            onChanged: (value) => setState(() => _role = value ?? 'member'),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (_name.text.trim().isEmpty) return;
              Navigator.pop(context, _MemberDraft(name: _name.text.trim(), email: _email.text.trim(), role: _role));
            },
            child: const Text('Add member'),
          ),
        ],
      );
}
