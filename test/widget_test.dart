import 'package:enish/data/events.dart';
import 'package:enish/data/locations.dart';
import 'package:enish/data/media.dart';
import 'package:enish/main.dart';
import 'package:enish/screens/staff.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Venue _venue(String code, String name, {bool confirmed = true}) => Venue(
      code: code,
      name: name,
      region: 'UK',
      city: 'London',
      status: VenueStatus.open,
      confirmed: confirmed,
      address: '1 Test St',
    );

void main() {
  test('Venue.fromJson maps database columns', () {
    final v = Venue.fromJson({
      'code': 'camden',
      'name': 'Enish Camden',
      'region': 'UK',
      'city': 'London',
      'status': 'open',
      'confirmed': true,
      'address': '392 Camden Rd, London N7 0SJ',
      'booking_system': 'tablemenu',
      'booking_url': 'https://enishcamden.tablemenu.co/reservation',
    });
    expect(v.isOpen, isTrue);
    expect(v.isVisible, isTrue);
    expect(v.bookingUrl, 'https://enishcamden.tablemenu.co/reservation');
  });

  test('unconfirmed or unknown venues are never visible', () {
    final hidden = Venue.fromJson({
      'code': 'covent-garden',
      'name': 'Enish Covent Garden',
      'status': 'unknown',
      'confirmed': false,
    });
    expect(hidden.isVisible, isFalse);
  });

  test('venues sort by region order, then name', () {
    Venue v(String code, String region) => Venue(
        code: code, name: code, region: region, city: '',
        status: VenueStatus.open, confirmed: true);
    final sorted = sortVenues([
      v('houston', 'USA'), v('dubai', 'UAE'), v('soho', 'UK'), v('camden', 'UK'),
    ]);
    expect(sorted.map((x) => x.code), ['camden', 'soho', 'dubai', 'houston']);
  });

  test('venue accent parses hex and falls back when missing', () {
    expect(
      Venue.fromJson({'code': 'a', 'name': 'A', 'accent_color': '#D7385E'}).accent,
      const Color(0xFFD7385E),
    );
    expect(Venue.fromJson({'code': 'b', 'name': 'B'}).accent.a, 1.0);
  });

  test('media library finds venue photos, art and intro video', () {
    const lib = MediaLibrary([
      MediaItem(kind: 'illustration', category: 'venue', url: 'u1',
          storagePath: 'venue/camden.png', venueCode: 'camden'),
      MediaItem(kind: 'photo', category: 'venue', url: 'u2',
          storagePath: 'venue/soho.jpg', venueCode: 'soho'),
      MediaItem(kind: 'photo', category: 'food', url: 'u3',
          storagePath: 'food/jollof.jpg', venueCode: 'camden', title: 'Jollof'),
    ]);
    expect(lib.venueArt('camden')?.url, 'u1');
    expect(lib.venuePhoto('camden'), isNull);
    expect(lib.venuePhoto('soho')?.url, 'u2');
    expect(lib.foodAt('camden').single.title, 'Jollof');
    expect(lib.introVideo, isNull);
    expect(lib.heroes.map((m) => m.url), containsAll(['u2', 'u3']));
  });

  test('uploaded clips become films, never photos', () {
    const lib = MediaLibrary([
      MediaItem(kind: 'video', category: 'happening', url: 'v1',
          storagePath: 'happening/camden/night.mp4', venueCode: 'camden'),
      MediaItem(kind: 'video', category: 'intro', url: 'v2',
          storagePath: 'intro/enish.mp4'),
      MediaItem(kind: 'photo', category: 'happening', url: 'p1',
          storagePath: 'happening/crowd.jpg'),
    ]);
    expect(lib.filmsAt('camden').single.url, 'v1');
    expect(lib.films.map((m) => m.url), ['v1']);
    expect(lib.happenings.map((m) => m.url), ['p1']);
    expect(lib.introVideo?.url, 'v2');
  });

  testWidgets('intro leads into the hub, then to a venue', (tester) async {
    final venues = [_venue('camden', 'Enish Camden')];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        venuesProvider.overrideWith((ref) async => venues),
        mediaProvider.overrideWith((ref) async => MediaLibrary.empty),
        upcomingEventsProvider.overrideWith((ref) async => const []),
        sessionProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: const EnishApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('GOOD FOOD, GOOD MOOD'), findsOneWidget);

    await tester.tap(find.text('ENTER ENISH'));
    await tester.pumpAndSettle();
    expect(find.text('CHOOSE YOUR ENISH'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.place_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ENISH CAMDEN'));
    await tester.pumpAndSettle();
    expect(find.text('BOOK A TABLE'), findsOneWidget);
  });

  test('events keep the venue wall-clock time both ways', () {
    final e = EnishEvent.fromJson({
      'id': 'x',
      'venue_code': 'houston',
      'title': 'Afrobeats Friday',
      'starts_local': '2026-12-05T21:00:00',
      'ends_local': '2026-12-06T02:00:00',
      'starts_at': '2026-12-06T03:00:00+00:00',
      'price_pence': 2550,
      'status': 'published',
    });
    expect(e.startsLocal, DateTime(2026, 12, 5, 21));
    expect(formatEventWhen(e), 'SAT 5 DEC · 9PM – 2AM');
    expect(formatPrice(e.priceMinor!, currencySymbol('houston', 'USA')), r'$25.50');
    final row = e.toRow();
    expect(row['starts_local'], '2026-12-05T21:00:00');
    expect(row.containsKey('starts_at'), isFalse);
    expect(row['status'], 'published');
  });

  test('prices parse from what staff type', () {
    expect(parsePrice(''), isNull);
    expect(parsePrice('25'), 2500);
    expect(parsePrice('£12.5'), 1250);
    expect(parsePrice('0'), 0);
    expect(formatPrice(0, '£'), 'FREE');
    expect(currencySymbol('dubai', 'UAE'), 'AED ');
  });

  test('staff access follows roles', () {
    final mgr = StaffAccess.fromRoles([
      {'role': 'venue_manager', 'venue_code': 'camden'},
    ]);
    expect(mgr.canEdit('camden'), isTrue);
    expect(mgr.canEdit('soho'), isFalse);
    expect(mgr.canEdit(null), isFalse);
    final admin = StaffAccess.fromRoles([
      {'role': 'group_admin', 'venue_code': null},
    ]);
    expect(admin.canEdit('soho'), isTrue);
    expect(admin.canEdit(null), isTrue);
    expect(StaffAccess.none.isStaff, isFalse);
  });

  testWidgets('event editor needs a name and a date before publishing',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        venuesProvider.overrideWith((ref) async => [_venue('camden', 'Enish Camden')]),
        staffAccessProvider.overrideWith((ref) async => StaffAccess.fromRoles([
              {'role': 'venue_manager', 'venue_code': 'camden'},
            ])),
      ],
      child: const MaterialApp(home: EventEditorScreen(venueCode: 'camden')),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PUBLISH'));
    await tester.pumpAndSettle();
    expect(find.text('Give the event a name'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Event name'), 'Brunch Party');
    await tester.tap(find.text('PUBLISH'));
    await tester.pump();
    expect(find.text('Choose a date and start time.'), findsOneWidget);
  });
}
