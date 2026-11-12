import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'locations.dart';

enum EventStatus { draft, published, cancelled }

/// One listed event. Times are the venue's own wall-clock time, exactly as
/// staff typed them; the database keeps the matching real instant for sorting.
@immutable
class EnishEvent {
  const EnishEvent({
    this.id,
    required this.venueCode,
    required this.title,
    required this.startsLocal,
    this.description = '',
    this.endsLocal,
    this.priceMinor,
    this.imageUrl,
    this.membersOnly = false,
    this.status = EventStatus.draft,
  });

  final String? id;

  /// Null for group-wide events.
  final String? venueCode;
  final String title;
  final String description;
  final DateTime startsLocal;
  final DateTime? endsLocal;

  /// Price in minor units (pence, fils, cents). Null means no price shown.
  final int? priceMinor;
  final String? imageUrl;
  final bool membersOnly;
  final EventStatus status;

  factory EnishEvent.fromJson(Map<String, dynamic> j) => EnishEvent(
        id: j['id'] as String?,
        venueCode: j['venue_code'] as String?,
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        startsLocal: _wallClock(j['starts_local'] ?? j['starts_at']),
        endsLocal: j['ends_local'] == null ? null : _wallClock(j['ends_local']),
        priceMinor: j['price_pence'] as int?,
        imageUrl: j['image_url'] as String?,
        membersOnly: j['members_only'] as bool? ?? false,
        status: switch (j['status'] as String?) {
          'published' => EventStatus.published,
          'cancelled' => EventStatus.cancelled,
          _ => EventStatus.draft,
        },
      );

  /// Columns staff write. starts_at/ends_at are derived by the database.
  Map<String, dynamic> toRow() => {
        'venue_code': venueCode,
        'title': title.trim(),
        'description': description.trim().isEmpty ? null : description.trim(),
        'starts_local': _iso(startsLocal),
        'ends_local': endsLocal == null ? null : _iso(endsLocal!),
        'price_pence': priceMinor,
        'image_url': imageUrl,
        'members_only': membersOnly,
        'status': status.name,
      };

  EnishEvent copyWith({EventStatus? status}) => EnishEvent(
        id: id,
        venueCode: venueCode,
        title: title,
        description: description,
        startsLocal: startsLocal,
        endsLocal: endsLocal,
        priceMinor: priceMinor,
        imageUrl: imageUrl,
        membersOnly: membersOnly,
        status: status ?? this.status,
      );

  /// Keeps the digits as written; never shifts into the device's time zone.
  static DateTime _wallClock(Object? v) {
    final s = (v as String).replaceFirst(RegExp(r'(Z|[+-]\d\d(:?\d\d)?)$'), '');
    final d = DateTime.parse(s);
    return DateTime(d.year, d.month, d.day, d.hour, d.minute);
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_pad2(d.month)}-${_pad2(d.day)}'
      'T${_pad2(d.hour)}:${_pad2(d.minute)}:00';
}

String _pad2(int n) => n.toString().padLeft(2, '0');

const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

/// "7PM", "10:30PM", "12AM".
String formatTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute == 0 ? '' : ':${_pad2(d.minute)}';
  return '$h$m${d.hour < 12 ? 'AM' : 'PM'}';
}

/// "FRI 5 DEC".
String formatDay(DateTime d) =>
    '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

/// "FRI 5 DEC · 7PM – 2AM".
String formatEventWhen(EnishEvent e) {
  final end = e.endsLocal;
  return '${formatDay(e.startsLocal)} · ${formatTime(e.startsLocal)}'
      '${end == null ? '' : ' – ${formatTime(end)}'}';
}

/// Currency by venue, since prices are typed in the venue's own money.
String currencySymbol(String? venueCode, String? region) => switch ((venueCode, region)) {
      ('accra', _) => 'GH₵',
      ('nairobi', _) => 'KSh ',
      (_, 'UAE') => 'AED ',
      (_, 'USA') => r'$',
      _ => '£',
    };

String formatPrice(int minor, String symbol) {
  if (minor == 0) return 'FREE';
  final whole = minor ~/ 100;
  final part = minor % 100;
  return '$symbol$whole${part == 0 ? '' : '.${_pad2(part)}'}';
}

/// Parses "25", "25.5", "£25.50" into minor units. Empty means no price.
int? parsePrice(String text) {
  final t = text.replaceAll(RegExp(r'[^0-9.]'), '');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  return v == null ? null : (v * 100).round();
}

// ---------------------------------------------------------------------------
// Guests
// ---------------------------------------------------------------------------

/// Published events from a few hours ago onwards, soonest first. Row-level
/// security already hides drafts and members-only events from guests.
Future<List<EnishEvent>> fetchUpcomingEvents() async {
  final since = DateTime.now().toUtc().subtract(const Duration(hours: 6));
  final rows = await Supabase.instance.client
      .from('events')
      .select()
      .eq('status', 'published')
      .gte('starts_at', since.toIso8601String())
      .order('starts_at');
  return [for (final r in rows) EnishEvent.fromJson(r)];
}

final upcomingEventsProvider =
    FutureProvider<List<EnishEvent>>((ref) => fetchUpcomingEvents());

extension EventsAt on List<EnishEvent> {
  List<EnishEvent> at(String venueCode) =>
      where((e) => e.venueCode == venueCode || e.venueCode == null).toList();
}

// ---------------------------------------------------------------------------
// Staff
// ---------------------------------------------------------------------------

SupabaseClient get _db => Supabase.instance.client;

/// The signed-in session, or null for guests.
final sessionProvider = StreamProvider<Session?>((ref) async* {
  final auth = _db.auth;
  yield auth.currentSession;
  yield* auth.onAuthStateChange.map((s) => s.session);
});

/// What the signed-in person may edit.
@immutable
class StaffAccess {
  const StaffAccess({this.isGroupAdmin = false, this.venueCodes = const {}});

  static const none = StaffAccess();

  final bool isGroupAdmin;
  final Set<String> venueCodes;

  bool get isStaff => isGroupAdmin || venueCodes.isNotEmpty;

  bool canEdit(String? venueCode) =>
      isGroupAdmin || (venueCode != null && venueCodes.contains(venueCode));

  factory StaffAccess.fromRoles(List<Map<String, dynamic>> rows) => StaffAccess(
        isGroupAdmin: rows.any((r) => r['role'] == 'group_admin'),
        venueCodes: {for (final r in rows) ?r['venue_code'] as String?},
      );
}

final staffAccessProvider = FutureProvider<StaffAccess>((ref) async {
  final userId = ref.watch(sessionProvider.select((s) => s.value?.user.id));
  if (userId == null) return StaffAccess.none;
  final rows = await _db.from('staff_roles').select().eq('user_id', userId);
  return StaffAccess.fromRoles(rows);
});

/// Every event for one venue (null = group-wide), drafts included.
final staffEventsProvider =
    FutureProvider.family<List<EnishEvent>, String?>((ref, venueCode) async {
  final base = _db.from('events').select();
  final rows = await (venueCode == null
          ? base.isFilter('venue_code', null)
          : base.eq('venue_code', venueCode))
      .order('starts_at');
  return [for (final r in rows) EnishEvent.fromJson(r)];
});

abstract final class StaffApi {
  static Future<void> signIn(String email, String password) =>
      _db.auth.signInWithPassword(email: email.trim(), password: password);

  static Future<void> signOut() => _db.auth.signOut();

  static Future<void> save(EnishEvent e) async {
    if (e.id == null) {
      await _db.from('events').insert(e.toRow());
    } else {
      await _db.from('events').update(e.toRow()).eq('id', e.id!);
    }
  }

  static Future<void> delete(String id) =>
      _db.from('events').delete().eq('id', id);

  /// Uploads a poster under the venue's folder and returns its public URL.
  static Future<String> uploadPoster({
    required String? venueCode,
    required Uint8List bytes,
    required String extension,
  }) async {
    final ext = switch (extension.toLowerCase()) {
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpg',
    };
    final path = '${venueCode ?? 'group'}/'
        '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final bucket = _db.storage.from('posters');
    await bucket.uploadBinary(path, bytes,
        fileOptions: FileOptions(
            contentType: ext == 'jpg' ? 'image/jpeg' : 'image/$ext'));
    return bucket.getPublicUrl(path);
  }

  static Future<List<Map<String, dynamic>>> team() async =>
      List<Map<String, dynamic>>.from(await _db.rpc('staff_directory'));

  static Future<void> grant(String email, String? venueCode, String role) =>
      _db.rpc('grant_staff_role', params: {
        'p_email': email,
        'p_venue_code': venueCode,
        'p_role': role,
      });

  static Future<void> revoke(String roleId) =>
      _db.from('staff_roles').delete().eq('id', roleId);
}

/// Venues a staff member can pick, in the usual order.
List<Venue> editableVenues(StaffAccess access, List<Venue> all) => [
      for (final v in all)
        if (access.canEdit(v.code)) v,
    ];
