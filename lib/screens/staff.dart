import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../brand/brand.dart';
import '../brand/visuals.dart';
import '../data/events.dart';
import '../data/locations.dart';

/// Readable message for anything Supabase throws at a staff action.
String _message(Object e) => switch (e) {
      AuthException(:final message) => message,
      PostgrestException(:final message) => message,
      StorageException(:final message) => message,
      _ => 'Something went wrong. Please try again.',
    };

void _toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// Encodes the venue choice for routes: '' is group-wide.
String _venueParam(String? code) => code ?? '';
String? _venueFromParam(String? p) => (p == null || p.isEmpty) ? null : p;

// ---------------------------------------------------------------------------
// Sign in
// ---------------------------------------------------------------------------

class StaffSignInScreen extends ConsumerStatefulWidget {
  const StaffSignInScreen({super.key});

  @override
  ConsumerState<StaffSignInScreen> createState() => _StaffSignInScreenState();
}

class _StaffSignInScreenState extends ConsumerState<StaffSignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await StaffApi.signIn(_email.text, _password.text);
      if (mounted) context.go('/account/staff');
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('STAFF SIGN IN')),
      body: ListView(
        padding: const EdgeInsets.all(EnishSpace.md),
        children: [
          const Text(
            'For Enish venue teams. Accounts are set up by head office.',
            style: EnishText.body,
          ),
          const SizedBox(height: EnishSpace.md),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
          ),
          TextField(
            controller: _password,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: EnishSpace.md),
            Text(_error!, style: const TextStyle(color: Color(0xFFE57373))),
          ],
          const SizedBox(height: EnishSpace.lg),
          EnishButton(label: _busy ? 'Signing in…' : 'Sign in',
              onPressed: _busy ? null : _submit),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Staff home: pick a venue, see its events
// ---------------------------------------------------------------------------

class StaffHomeScreen extends ConsumerStatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  ConsumerState<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends ConsumerState<StaffHomeScreen> {
  /// Selected venue; null with [_picked] true means group-wide.
  String? _venue;
  bool _picked = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).value;
    final accessAsync = ref.watch(staffAccessProvider);
    final allVenues = ref.watch(venuesProvider).value ?? const <Venue>[];

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('STAFF')),
        body: Padding(
          padding: const EdgeInsets.all(EnishSpace.md),
          child: EnishButton(
            label: 'Staff sign in',
            onPressed: () => context.go('/account/sign-in'),
          ),
        ),
      );
    }

    return accessAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('STAFF')),
        body: Center(child: Text(_message(e), style: EnishText.body)),
      ),
      data: (access) {
        if (!access.isStaff) {
          return Scaffold(
            appBar: AppBar(title: const Text('STAFF')),
            body: const Padding(
              padding: EdgeInsets.all(EnishSpace.md),
              child: EnishComingSoon(
                message: 'This account has no venue access yet. Ask head '
                    'office to add you to your venue.',
              ),
            ),
          );
        }
        final venues = editableVenues(access, allVenues);
        if (!_picked) {
          _venue = venues.isNotEmpty ? venues.first.code : null;
        }
        final selected = venues.where((v) => v.code == _venue).firstOrNull;
        final events = ref.watch(staffEventsProvider(_venue));

        return Scaffold(
          appBar: AppBar(
            title: const Text('MANAGE EVENTS'),
            actions: [
              if (access.isGroupAdmin)
                IconButton(
                  tooltip: 'Team',
                  icon: const Icon(Icons.group_outlined),
                  onPressed: () => context.go('/account/staff/team'),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: selected?.accent ?? EnishColors.oxblood,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('NEW EVENT'),
            onPressed: () => context.go(
                '/account/staff/new?venue=${_venueParam(_venue)}'),
          ),
          body: RefreshIndicator(
            onRefresh: () => ref.refresh(staffEventsProvider(_venue).future),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      EnishSpace.md, EnishSpace.md, EnishSpace.md, 0),
                  child: _VenuePicker(
                    venues: venues,
                    allowGroup: access.isGroupAdmin,
                    value: _venue,
                    onChanged: (code) => setState(() {
                      _venue = code;
                      _picked = true;
                    }),
                  ),
                ),
                ...events.when(
                  loading: () => const [
                    Padding(
                      padding: EdgeInsets.all(EnishSpace.xl),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  error: (e, _) => [
                    Padding(
                      padding: const EdgeInsets.all(EnishSpace.md),
                      child: Text(_message(e), style: EnishText.body),
                    ),
                  ],
                  data: (list) => _eventSections(context, list, selected),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _eventSections(
      BuildContext context, List<EnishEvent> list, Venue? venue) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 6));
    final upcoming = list.where((e) => !e.startsLocal.isBefore(cutoff)).toList();
    final past = list.where((e) => e.startsLocal.isBefore(cutoff)).toList().reversed;
    if (list.isEmpty) {
      return const [
        SizedBox(height: EnishSpace.md),
        EnishComingSoon(message: 'No events yet. Tap New event to add one.'),
      ];
    }
    return [
      const EnishSectionHeader(title: 'Coming up'),
      if (upcoming.isEmpty)
        const EnishComingSoon(message: 'Nothing scheduled.'),
      for (final e in upcoming) _StaffEventRow(event: e, venue: venue),
      if (past.isNotEmpty) ...[
        const EnishSectionHeader(title: 'Past'),
        for (final e in past.take(20)) _StaffEventRow(event: e, venue: venue),
      ],
    ];
  }
}

class _VenuePicker extends StatelessWidget {
  const _VenuePicker({
    required this.venues,
    required this.allowGroup,
    required this.value,
    required this.onChanged,
  });

  final List<Venue> venues;
  final bool allowGroup;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: _venueParam(value),
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Venue'),
      items: [
        for (final v in venues)
          DropdownMenuItem(value: v.code, child: Text(v.name)),
        if (allowGroup)
          const DropdownMenuItem(value: '', child: Text('Every Enish (group-wide)')),
      ],
      onChanged: (v) => onChanged(_venueFromParam(v)),
    );
  }
}

class _StaffEventRow extends StatelessWidget {
  const _StaffEventRow({required this.event, required this.venue});

  final EnishEvent event;
  final Venue? venue;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (event.status) {
      EventStatus.published => ('LIVE', const Color(0xFF2E9E6B)),
      EventStatus.draft => ('DRAFT', EnishColors.muted),
      EventStatus.cancelled => ('CANCELLED', const Color(0xFFE57373)),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: EnishSpace.md, vertical: EnishSpace.xs),
      child: PhotoCard(
        onTap: () => context.go('/account/staff/edit', extra: event),
        child: SizedBox(
          height: 92,
          child: Row(children: [
            SizedBox(
              width: 72,
              height: 92,
              child: event.imageUrl != null
                  ? EnishPhoto(url: event.imageUrl!, alignment: Alignment.topCenter)
                  : ColoredBox(
                      color: venue?.accent ?? EnishColors.oxblood,
                      child: const Icon(Icons.event, color: Colors.white70)),
            ),
            const SizedBox(width: EnishSpace.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EnishText.label),
                  const SizedBox(height: 4),
                  Text(formatEventWhen(event),
                      style: EnishText.body.copyWith(fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 10, letterSpacing: 1.4,
                            fontWeight: FontWeight.w700, color: color)),
                    if (event.membersOnly) ...[
                      const SizedBox(width: EnishSpace.sm),
                      const Text('INSIDER',
                          style: TextStyle(
                              fontSize: 10, letterSpacing: 1.4,
                              fontWeight: FontWeight.w700,
                              color: EnishColors.gold)),
                    ],
                  ]),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: EnishColors.muted),
            const SizedBox(width: EnishSpace.sm),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Event editor
// ---------------------------------------------------------------------------

class EventEditorScreen extends ConsumerStatefulWidget {
  const EventEditorScreen({super.key, this.event, this.venueCode});

  /// Null for a new event.
  final EnishEvent? event;

  /// Venue for a new event (null = group-wide).
  final String? venueCode;

  @override
  ConsumerState<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends ConsumerState<EventEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late String? _venue;
  DateTime? _date;
  TimeOfDay? _start;
  TimeOfDay? _end;
  late bool _membersOnly;
  String? _imageUrl;
  Uint8List? _posterBytes;
  String _posterExt = 'jpg';
  bool _busy = false;

  bool get _isNew => widget.event == null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _price = TextEditingController(
        text: e?.priceMinor == null
            ? ''
            : (e!.priceMinor! / 100).toStringAsFixed(e.priceMinor! % 100 == 0 ? 0 : 2));
    _venue = e?.venueCode ?? widget.venueCode;
    if (e != null) {
      final s = e.startsLocal;
      _date = DateTime(s.year, s.month, s.day);
      _start = TimeOfDay(hour: s.hour, minute: s.minute);
      final end = e.endsLocal;
      if (end != null) _end = TimeOfDay(hour: end.hour, minute: end.minute);
    }
    _membersOnly = e?.membersOnly ?? false;
    _imageUrl = e?.imageUrl;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickPoster() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final name = file.name.toLowerCase();
    setState(() {
      _posterBytes = bytes;
      _posterExt = name.contains('.') ? name.split('.').last : 'jpg';
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime({required bool start}) async {
    final t = await showTimePicker(
      context: context,
      initialTime: (start ? _start : _end) ?? const TimeOfDay(hour: 19, minute: 0),
    );
    if (t != null) setState(() => start ? _start = t : _end = t);
  }

  /// Builds the event, or returns null after explaining what is missing.
  EnishEvent? _build(EventStatus status) {
    if (!_form.currentState!.validate()) return null;
    if (_date == null || _start == null) {
      _toast(context, 'Choose a date and start time.');
      return null;
    }
    final d = _date!;
    final starts = DateTime(d.year, d.month, d.day, _start!.hour, _start!.minute);
    DateTime? ends;
    if (_end != null) {
      ends = DateTime(d.year, d.month, d.day, _end!.hour, _end!.minute);
      // Late nights: an end time at or before the start is the next morning.
      if (!ends.isAfter(starts)) ends = ends.add(const Duration(days: 1));
    }
    return EnishEvent(
      id: widget.event?.id,
      venueCode: _venue,
      title: _title.text,
      description: _description.text,
      startsLocal: starts,
      endsLocal: ends,
      priceMinor: parsePrice(_price.text),
      imageUrl: _imageUrl,
      membersOnly: _membersOnly,
      status: status,
    );
  }

  Future<void> _save(EventStatus status) async {
    final event = _build(status);
    if (event == null) return;
    setState(() => _busy = true);
    try {
      var toSave = event;
      if (_posterBytes != null) {
        final url = await StaffApi.uploadPoster(
            venueCode: _venue, bytes: _posterBytes!, extension: _posterExt);
        _imageUrl = url;
        _posterBytes = null;
        toSave = _build(status)!;
      }
      await StaffApi.save(toSave);
      _refreshLists();
      if (!mounted) return;
      _toast(context, switch (status) {
        EventStatus.published => 'Published. Guests can see it now.',
        EventStatus.draft => 'Saved as a draft. Guests can’t see it.',
        EventStatus.cancelled => 'Marked as cancelled and hidden from guests.',
      });
      context.go('/account/staff');
    } catch (e) {
      if (mounted) _toast(context, _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this event?'),
        content: const Text('It will be removed for good. To keep a record '
            'but hide it from guests, cancel it instead.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('KEEP')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('DELETE')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await StaffApi.delete(widget.event!.id!);
      _refreshLists();
      if (mounted) context.go('/account/staff');
    } catch (e) {
      if (mounted) _toast(context, _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refreshLists() {
    ref.invalidate(staffEventsProvider);
    ref.invalidate(upcomingEventsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(staffAccessProvider).value ?? StaffAccess.none;
    final allVenues = ref.watch(venuesProvider).value ?? const <Venue>[];
    final venues = editableVenues(access, allVenues);
    final venue = allVenues.where((v) => v.code == _venue).firstOrNull;
    final accent = venue?.accent ?? EnishColors.oxblood;
    final symbol = currencySymbol(_venue, venue?.region).trim();

    String timeLabel(TimeOfDay? t) => t == null
        ? 'Choose'
        : formatTime(DateTime(2000, 1, 1, t.hour, t.minute));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'NEW EVENT' : 'EDIT EVENT'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _delete,
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(EnishSpace.md),
            children: [
              _PosterPicker(
                bytes: _posterBytes,
                url: _imageUrl,
                accent: accent,
                onPick: _pickPoster,
                onRemove: () => setState(() {
                  _posterBytes = null;
                  _imageUrl = null;
                }),
              ),
              const SizedBox(height: EnishSpace.md),
              _VenuePicker(
                venues: venues,
                allowGroup: access.isGroupAdmin,
                value: _venue,
                onChanged: (v) => setState(() => _venue = v),
              ),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Event name'),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Give the event a name' : null,
              ),
              const SizedBox(height: EnishSpace.md),
              Row(children: [
                Expanded(
                  flex: 3,
                  child: _PickerField(
                    label: 'Date',
                    value: _date == null ? 'Choose' : formatDay(_date!),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: EnishSpace.sm),
                Expanded(
                  flex: 2,
                  child: _PickerField(
                    label: 'Starts',
                    value: timeLabel(_start),
                    onTap: () => _pickTime(start: true),
                  ),
                ),
                const SizedBox(width: EnishSpace.sm),
                Expanded(
                  flex: 2,
                  child: _PickerField(
                    label: 'Ends',
                    value: _end == null ? 'Optional' : timeLabel(_end),
                    onTap: () => _pickTime(start: false),
                    onClear: _end == null ? null : () => setState(() => _end = null),
                  ),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.only(top: EnishSpace.xs),
                child: Text(
                  'Times are local to ${venue?.city ?? 'London'}.',
                  style: EnishText.body.copyWith(fontSize: 12),
                ),
              ),
              TextFormField(
                controller: _price,
                decoration: InputDecoration(
                  labelText: 'Price (optional, 0 for free)',
                  prefixText: '$symbol ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  hintText: 'Line-up, dress code, how to book…',
                ),
                minLines: 3,
                maxLines: 8,
              ),
              const SizedBox(height: EnishSpace.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _membersOnly,
                onChanged: (v) => setState(() => _membersOnly = v),
                title: const Text('Insider members only', style: EnishText.label),
                subtitle: const Text(
                  'Hidden from guests until Insider membership launches.',
                  style: TextStyle(fontSize: 12, color: EnishColors.muted),
                ),
              ),
              const SizedBox(height: EnishSpace.lg),
              EnishButton(
                label: _busy ? 'Saving…' : 'Publish',
                color: accent,
                onPressed: _busy ? null : () => _save(EventStatus.published),
              ),
              const SizedBox(height: EnishSpace.sm),
              EnishButton(
                label: 'Save as draft',
                primary: false,
                onPressed: _busy ? null : () => _save(EventStatus.draft),
              ),
              if (!_isNew && widget.event!.status != EventStatus.cancelled) ...[
                const SizedBox(height: EnishSpace.sm),
                TextButton(
                  onPressed: _busy ? null : () => _save(EventStatus.cancelled),
                  child: const Text('CANCEL THIS EVENT',
                      style: TextStyle(color: Color(0xFFE57373), letterSpacing: 1.4)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onClear,
                ),
        ),
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _PosterPicker extends StatelessWidget {
  const _PosterPicker({
    required this.bytes,
    required this.url,
    required this.accent,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? bytes;
  final String? url;
  final Color accent;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final has = bytes != null || url != null;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: PhotoCard(
        onTap: onPick,
        child: Stack(fit: StackFit.expand, children: [
          if (bytes != null)
            Image.memory(bytes!, fit: BoxFit.contain)
          else if (url != null)
            EnishPhoto(url: url!, fit: BoxFit.contain)
          else
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: accent, width: 1.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, color: accent, size: 40),
                  const SizedBox(height: EnishSpace.sm),
                  const Text('ADD A POSTER', style: EnishText.label),
                  const SizedBox(height: 2),
                  Text('Optional', style: EnishText.body.copyWith(fontSize: 12)),
                ],
              ),
            ),
          if (has)
            Positioned(
              right: 8,
              top: 8,
              child: Row(children: [
                IconButton.filledTonal(
                  tooltip: 'Change poster',
                  icon: const Icon(Icons.edit),
                  onPressed: onPick,
                ),
                IconButton.filledTonal(
                  tooltip: 'Remove poster',
                  icon: const Icon(Icons.close),
                  onPressed: onRemove,
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Team (group admins)
// ---------------------------------------------------------------------------

final _teamProvider = FutureProvider.autoDispose((ref) => StaffApi.team());

const _roleNames = {
  'venue_manager': 'Venue manager',
  'venue_editor': 'Venue editor',
  'group_admin': 'Group admin (every venue)',
};

class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  final _email = TextEditingController();
  String _role = 'venue_manager';
  String? _venue;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_email.text.trim().isEmpty) return _toast(context, 'Enter their email.');
    if (_role != 'group_admin' && _venue == null) {
      return _toast(context, 'Choose their venue.');
    }
    setState(() => _busy = true);
    try {
      await StaffApi.grant(_email.text, _venue, _role);
      _email.clear();
      ref.invalidate(_teamProvider);
      if (mounted) _toast(context, 'Access added.');
    } catch (e) {
      if (mounted) _toast(context, _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> row) async {
    try {
      await StaffApi.revoke(row['id'] as String);
      ref.invalidate(_teamProvider);
      ref.invalidate(staffAccessProvider);
    } catch (e) {
      if (mounted) _toast(context, _message(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = ref.watch(_teamProvider);
    final venues = ref.watch(venuesProvider).value ?? const <Venue>[];
    final names = {for (final v in venues) v.code: v.name};

    return Scaffold(
      appBar: AppBar(title: const Text('TEAM')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: EnishSpace.xl),
        children: [
          const EnishSectionHeader(eyebrow: 'Give access', title: 'Add someone'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: EnishSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create their login in Supabase first (Authentication › '
                  'Users › Add user), then give it access here.',
                  style: EnishText.body,
                ),
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Their email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: [
                    for (final r in _roleNames.entries)
                      DropdownMenuItem(value: r.key, child: Text(r.value)),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? _role),
                ),
                if (_role != 'group_admin')
                  DropdownButtonFormField<String>(
                    initialValue: _venue,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Venue'),
                    items: [
                      for (final v in venues)
                        DropdownMenuItem(value: v.code, child: Text(v.name)),
                    ],
                    onChanged: (v) => setState(() => _venue = v),
                  ),
                const SizedBox(height: EnishSpace.md),
                EnishButton(label: 'Add access', onPressed: _busy ? null : _add),
              ],
            ),
          ),
          const EnishSectionHeader(title: 'Who has access'),
          ...team.when(
            loading: () => const [Center(child: CircularProgressIndicator())],
            error: (e, _) => [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: EnishSpace.md),
                child: Text(_message(e), style: EnishText.body),
              ),
            ],
            data: (rows) => [
              for (final r in rows)
                ListTile(
                  title: Text(r['email'] as String? ?? ''),
                  subtitle: Text(
                    r['role'] == 'group_admin'
                        ? 'Group admin'
                        : '${_roleNames[r['role']]} · '
                            '${names[r['venue_code']] ?? r['venue_code']}',
                    style: EnishText.body.copyWith(fontSize: 12),
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove access',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _remove(r),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
