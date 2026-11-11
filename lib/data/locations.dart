import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum VenueStatus { open, comingSoon, unknown }

/// One Enish venue, read from the `venues` table. Row-level security means
/// guests only ever receive published venues.
class Venue {
  const Venue({
    required this.code,
    required this.name,
    required this.region,
    required this.city,
    required this.status,
    required this.confirmed,
    this.address = '',
    this.phone = '',
    this.hours = '',
    this.bookingSystem = '',
    this.bookingUrl = '',
    this.eventsEmail = '',
    this.accentHex,
  });

  /// Display order for regions, so the home market leads.
  static const regionOrder = ['UK', 'UAE', 'USA', 'Africa'];

  final String code;
  final String name;
  final String region;
  final String city;
  final VenueStatus status;
  final bool confirmed;
  final String address;
  final String phone;
  final String hours;
  final String bookingSystem;
  final String bookingUrl;
  final String eventsEmail;
  final String? accentHex;

  /// The venue's own colour, or a stable fallback from the brand palette.
  Color get accent {
    final hex = accentHex;
    if (hex != null && RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) {
      return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
    }
    const fallback = [
      Color(0xFFD7385E), Color(0xFF2E9E6B), Color(0xFFF2A93B),
      Color(0xFF4C5FD5), Color(0xFFF06A2B), Color(0xFF1FA2A6),
    ];
    return fallback[code.codeUnits.fold<int>(0, (a, b) => a + b) % fallback.length];
  }

  bool get isOpen => status == VenueStatus.open;

  /// Unconfirmed candidates never reach guests, even if a row is published.
  bool get isVisible => confirmed && status != VenueStatus.unknown;

  factory Venue.fromJson(Map<String, dynamic> j) => Venue(
        code: j['code'] as String,
        name: j['name'] as String,
        region: j['region'] as String? ?? '',
        city: j['city'] as String? ?? '',
        status: switch (j['status'] as String?) {
          'open' => VenueStatus.open,
          'coming_soon' => VenueStatus.comingSoon,
          _ => VenueStatus.unknown,
        },
        confirmed: j['confirmed'] as bool? ?? false,
        address: j['address'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        hours: j['hours'] as String? ?? '',
        bookingSystem: j['booking_system'] as String? ?? '',
        bookingUrl: j['booking_url'] as String? ?? '',
        eventsEmail: j['events_email'] as String? ?? '',
        accentHex: j['accent_color'] as String?,
      );
}

/// Loads venues from Supabase. Ordering keeps regions and cities stable
/// across devices.
Future<List<Venue>> fetchVenues() async {
  final rows = await Supabase.instance.client
      .from('venues')
      .select()
      .eq('published', true)
      .order('region')
      .order('name');
  final venues = [
    for (final r in rows) Venue.fromJson(r),
  ].where((v) => v.isVisible).toList();
  return sortVenues(venues);
}

/// Region order first (UK, UAE, USA, Africa, then anything new), then name.
List<Venue> sortVenues(List<Venue> venues) {
  int rank(Venue v) {
    final i = Venue.regionOrder.indexOf(v.region);
    return i == -1 ? Venue.regionOrder.length : i;
  }

  return [...venues]..sort((a, b) {
      final byRegion = rank(a).compareTo(rank(b));
      return byRegion != 0 ? byRegion : a.name.compareTo(b.name);
    });
}

final venuesProvider = FutureProvider<List<Venue>>((ref) => fetchVenues());

/// The guest's chosen "home" Enish. In memory for now; persist with the
/// account once sign-in exists.
class HomeVenueNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? code) => state = code;
}

final homeVenueProvider =
    NotifierProvider<HomeVenueNotifier, String?>(HomeVenueNotifier.new);
