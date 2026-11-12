import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../brand/brand.dart';
import '../brand/visuals.dart';
import '../data/locations.dart';
import '../data/events.dart';
import '../data/media.dart';
import 'event_card.dart';

Future<void> _open(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    messenger.showSnackBar(SnackBar(content: Text('Could not open $uri')));
  }
}

String _dialable(String phone) => phone.replaceAll(RegExp(r'[^0-9+]'), '');

/// One booking entry point for every venue, whatever system sits behind it.
/// Falls back to a phone call where no booking link is on record.
Future<void> bookVenue(BuildContext context, Venue v) async {
  if (v.bookingUrl.isNotEmpty) {
    return _open(context, Uri.parse(v.bookingUrl));
  }
  if (v.phone.isNotEmpty) {
    return _open(context, Uri(scheme: 'tel', path: _dialable(v.phone)));
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Booking details for ${v.name} are not set yet.')),
  );
}

const _regionNames = {
  'UK': 'United Kingdom',
  'UAE': 'United Arab Emirates',
  'USA': 'United States',
  'Africa': 'Africa',
};

class VenuesScreen extends ConsumerWidget {
  const VenuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venues = ref.watch(venuesProvider);
    final media = ref.watch(mediaProvider).value ?? MediaLibrary.empty;
    return Scaffold(
      appBar: AppBar(title: const Text('VENUES')),
      body: venues.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load venues: $e')),
        data: (all) {
          final open = all.where((v) => v.isOpen).toList();
          final regions = [
            ...Venue.regionOrder.where((r) => open.any((v) => v.region == r)),
            ...{for (final v in open) v.region}
                .where((r) => !Venue.regionOrder.contains(r)),
          ];
          final soon = all.where((v) => !v.isOpen).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: EnishSpace.xl),
            children: [
              for (final region in regions) ...[
                EnishSectionHeader(
                  eyebrow: '${open.where((v) => v.region == region).length} venues',
                  title: _regionNames[region] ?? region,
                ),
                for (final v in open.where((v) => v.region == region))
                  _VenueCard(venue: v, media: media),
              ],
              if (soon.isNotEmpty) ...[
                const EnishSectionHeader(eyebrow: 'Next chapter', title: 'Coming soon'),
                for (final v in soon) _VenueCard(venue: v, media: media, comingSoon: true),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({
    required this.venue,
    required this.media,
    this.comingSoon = false,
  });

  final Venue venue;
  final MediaLibrary media;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          EnishSpace.md, 0, EnishSpace.md, EnishSpace.sm + 4),
      child: SizedBox(
        height: 180,
        child: PhotoCard(
          radius: 16,
          onTap: comingSoon ? null : () => context.go('/venues/${venue.code}'),
          child: VenueArt(
            venue: venue,
            media: media,
            child: Padding(
              padding: const EdgeInsets.all(EnishSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (comingSoon)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('COMING SOON', style: EnishText.label),
                    ),
                  const Spacer(),
                  Text(
                    venue.city.toUpperCase(),
                    style: EnishText.eyebrow.copyWith(
                      color: Color.lerp(venue.accent, Colors.white, 0.45),
                    ),
                  ),
                  const SizedBox(height: EnishSpace.xs),
                  Row(children: [
                    Expanded(
                      child: Text(
                        venue.name.toUpperCase(),
                        style: EnishText.title.copyWith(fontSize: 20),
                      ),
                    ),
                    if (!comingSoon)
                      const Icon(Icons.arrow_forward, color: EnishColors.cream),
                  ]),
                  if (venue.address.isNotEmpty) ...[
                    const SizedBox(height: EnishSpace.xs),
                    Text(
                      venue.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: EnishColors.cream),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The venue hub. Every location renders through this one template, which is
/// what keeps the experience identical from Lewisham to Dubai.
class VenueScreen extends ConsumerWidget {
  const VenueScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venue = ref
        .watch(venuesProvider)
        .value
        ?.where((v) => v.code == code)
        .firstOrNull;
    if (venue == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Venue not found')),
      );
    }
    final media = ref.watch(mediaProvider).value ?? MediaLibrary.empty;
    final isHome = ref.watch(homeVenueProvider) == code;
    final accent = venue.accent;

    final films = media.filmsAt(code);
    final events = media.eventsAt(code);
    final listed =
        (ref.watch(upcomingEventsProvider).value ?? const <EnishEvent>[]).at(code);
    final ownFood = media.foodAt(code);
    final food = ownFood.isNotEmpty ? ownFood : media.food.take(12).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 360,
            backgroundColor: Color.lerp(accent, Colors.black, 0.6),
            actions: [
              IconButton(
                tooltip: isHome ? 'Your Enish' : 'Make this your Enish',
                icon: Icon(
                  isHome ? Icons.favorite : Icons.favorite_border,
                  color: isHome ? EnishColors.gold : EnishColors.cream,
                ),
                onPressed: () => ref
                    .read(homeVenueProvider.notifier)
                    .set(isHome ? null : code),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 16),
              title: Text(venue.name.toUpperCase(),
                  style: EnishText.title.copyWith(fontSize: 15)),
              // The venue's first clip plays silently behind its name.
              background: films.isEmpty
                  ? VenueArt(venue: venue, media: media)
                  : Stack(fit: StackFit.expand, children: [
                      LoopingVideo(
                        url: films.first.url,
                        placeholder: VenueArt(venue: venue, media: media),
                      ),
                      const PhotoScrim(strength: 0.75),
                    ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(EnishSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EnishButton(
                    label: 'Book a table',
                    color: accent,
                    onPressed: () => bookVenue(context, venue),
                  ),
                  const SizedBox(height: EnishSpace.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (venue.phone.isNotEmpty)
                        _RoundAction(
                          icon: Icons.phone_outlined,
                          label: 'Call',
                          color: accent,
                          onTap: () => _open(
                            context,
                            Uri(scheme: 'tel', path: _dialable(venue.phone)),
                          ),
                        ),
                      if (venue.address.isNotEmpty)
                        _RoundAction(
                          icon: Icons.near_me_outlined,
                          label: 'Directions',
                          color: accent,
                          onTap: () => _open(
                            context,
                            Uri.https('www.google.com', '/maps/search/', {
                              'api': '1',
                              'query': '${venue.name}, ${venue.address}',
                            }),
                          ),
                        ),
                      _RoundAction(
                        icon: Icons.celebration_outlined,
                        label: 'Host an event',
                        color: accent,
                        onTap: () => context.go('/venues/$code/enquire'),
                      ),
                    ],
                  ),
                  const SizedBox(height: EnishSpace.lg),
                  Container(
                    padding: const EdgeInsets.all(EnishSpace.md),
                    decoration: BoxDecoration(
                      color: EnishColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border(left: BorderSide(color: accent, width: 4)),
                    ),
                    child: Column(children: [
                      if (venue.address.isNotEmpty)
                        _InfoRow(icon: Icons.place_outlined, text: venue.address, color: accent),
                      if (venue.hours.isNotEmpty)
                        _InfoRow(icon: Icons.schedule, text: venue.hours, color: accent),
                      if (venue.phone.isNotEmpty)
                        _InfoRow(icon: Icons.phone_outlined, text: venue.phone, color: accent),
                    ]),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: PhotoStrip(
              eyebrow: 'Watch',
              title: 'Films',
              height: 220,
              itemWidth: 150,
              itemCount: films.length,
              itemBuilder: (context, i) => FilmTile(item: films[i], color: accent),
            ),
          ),
          SliverToBoxAdapter(
            child: PhotoStrip(
              eyebrow: 'Happening here',
              title: "What's on",
              height: 240,
              itemWidth: 180,
              // Listed events first (soonest first), then the venue's posters.
              itemCount: listed.length + events.length,
              itemBuilder: (context, i) => i < listed.length
                  ? EventCard(event: listed[i], venue: venue)
                  : PhotoCard(
                      onTap: () => showPhoto(context, events[i - listed.length]),
                      child: EnishPhoto(
                          url: events[i - listed.length].url,
                          alignment: Alignment.topCenter),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: PhotoStrip(
              eyebrow: ownFood.isNotEmpty ? 'On the menu here' : 'From the Enish kitchen',
              title: 'Signature dishes',
              height: 180,
              itemWidth: 160,
              itemCount: food.length,
              itemBuilder: (context, i) => CaptionedPhoto(item: food[i]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: EnishSpace.xl)),
        ],
      ),
    );
  }
}

/// Circular icon action with a caption, tinted with the venue's colour.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(EnishSpace.xs),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
              border: Border.all(color: color.withValues(alpha: 0.7)),
            ),
            child: Icon(icon, color: Color.lerp(color, Colors.white, 0.35)),
          ),
          const SizedBox(height: EnishSpace.sm),
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10, letterSpacing: 1.2, color: EnishColors.cream)),
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: EnishSpace.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Color.lerp(color, Colors.white, 0.3)),
          const SizedBox(width: EnishSpace.md),
          Expanded(child: Text(text, style: EnishText.body)),
        ],
      ),
    );
  }
}

class EnquiryScreen extends ConsumerStatefulWidget {
  const EnquiryScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<EnquiryScreen> createState() => _EnquiryScreenState();
}

class _EnquiryScreenState extends ConsumerState<EnquiryScreen> {
  final _form = GlobalKey<FormState>();

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final venue = ref
        .watch(venuesProvider)
        .value
        ?.where((v) => v.code == widget.code)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('EVENT ENQUIRY')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(EnishSpace.md),
          children: [
            Text((venue?.name ?? '').toUpperCase(),
                style: EnishText.eyebrow.copyWith(color: venue?.accent)),
            const SizedBox(height: EnishSpace.sm),
            const Text(
              'Tell us about your event and the venue team will be in touch.',
              style: EnishText.body,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Name'),
              validator: _required,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: _required,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Type of event'),
              validator: _required,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Preferred date'),
              validator: _required,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Number of guests'),
              keyboardType: TextInputType.number,
              validator: _required,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Anything else'),
              maxLines: 3,
            ),
            const SizedBox(height: EnishSpace.lg),
            EnishButton(
              label: 'Send enquiry',
              color: venue?.accent,
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                // TODO(backend): post to the enquiries endpoint, routed to the
                // venue's events contact. Nothing is sent yet.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Enquiry sending is not connected yet. Nothing was sent.',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
