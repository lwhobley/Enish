import 'package:flutter/material.dart';

import '../brand/brand.dart';
import '../brand/visuals.dart';
import '../data/events.dart';
import '../data/locations.dart';
import 'venues.dart' show bookVenue;

/// A listed event as a poster tile: the poster (or the venue's colour), a
/// date badge, and the title.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.venue});

  final EnishEvent event;
  final Venue? venue;

  @override
  Widget build(BuildContext context) {
    final accent = venue?.accent ?? EnishColors.oxblood;
    final d = event.startsLocal;
    return PhotoCard(
      onTap: () => showEventDetails(context, event, venue),
      child: Stack(fit: StackFit.expand, children: [
        if (event.imageUrl != null)
          EnishPhoto(url: event.imageUrl!, alignment: Alignment.topCenter)
        else
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [accent, Color.lerp(accent, Colors.black, 0.65)!],
              ),
            ),
          ),
        const PhotoScrim(strength: 0.85),
        Positioned(
          left: 10,
          top: 10,
          child: Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(children: [
              Text(formatDay(d).split(' ').last,
                  style: const TextStyle(
                      fontSize: 10, letterSpacing: 1.2,
                      fontWeight: FontWeight.w700, color: Colors.white)),
              Text('${d.day}',
                  style: const TextStyle(
                      fontSize: 20, height: 1.1,
                      fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
          ),
        ),
        OverlayCaption(
          eyebrow: [
            if (venue != null) venue!.city,
            formatTime(d),
          ].join(' · '),
          eyebrowColor: Color.lerp(accent, Colors.white, 0.4),
          title: event.title,
          titleSize: 14,
        ),
      ]),
    );
  }
}

/// Bottom sheet with the full listing and a way to book.
Future<void> showEventDetails(
    BuildContext context, EnishEvent e, Venue? venue) {
  final accent = venue?.accent ?? EnishColors.gold;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: EnishColors.surface,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(
            EnishSpace.md, 0, EnishSpace.md, EnishSpace.xl),
        children: [
          if (e.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: Image.network(e.imageUrl!, fit: BoxFit.contain),
              ),
            ),
          const SizedBox(height: EnishSpace.md),
          Text(
            (venue?.name ?? 'Every Enish').toUpperCase(),
            style: EnishText.eyebrow.copyWith(color: accent),
          ),
          const SizedBox(height: EnishSpace.xs),
          Text(e.title.toUpperCase(), style: EnishText.display.copyWith(fontSize: 24)),
          const SizedBox(height: EnishSpace.sm),
          Text(formatEventWhen(e), style: EnishText.label.copyWith(color: accent)),
          if (e.priceMinor != null) ...[
            const SizedBox(height: EnishSpace.xs),
            Text(
              formatPrice(e.priceMinor!, currencySymbol(e.venueCode, venue?.region)),
              style: EnishText.label,
            ),
          ],
          if (e.description.isNotEmpty) ...[
            const SizedBox(height: EnishSpace.md),
            Text(e.description, style: EnishText.body),
          ],
          if (venue != null) ...[
            const SizedBox(height: EnishSpace.lg),
            EnishButton(
              label: 'Book a table',
              color: venue.accent,
              onPressed: () => bookVenue(context, venue),
            ),
          ],
        ],
      ),
    ),
  );
}
