import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../brand/brand.dart';
import '../brand/visuals.dart';
import '../data/locations.dart';
import '../data/media.dart';
import '../data/events.dart';
import 'event_card.dart';
import 'venues.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venues = ref.watch(venuesProvider);
    final media = ref.watch(mediaProvider).value ?? MediaLibrary.empty;
    final homeCode = ref.watch(homeVenueProvider);

    return Scaffold(
      body: venues.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load venues: $e')),
        data: (all) {
          final open = all.where((v) => v.isOpen).toList();
          final home = open.where((v) => v.code == homeCode).firstOrNull;
          final events = media.events;
          final listed = (ref.watch(upcomingEventsProvider).value ??
                  const <EnishEvent>[])
              .take(12)
              .toList();
          final films = media.films;
          final food = media.food;
          final experiences = media.experiences;

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _HeroCarousel(media: media),
              if (home != null)
                _YourEnish(venue: home, media: media)
              else
                _ChooseHome(onChoose: () => context.go('/venues')),
              PhotoStrip(
                eyebrow: 'Good food, good mood',
                title: 'Discover Enish',
                height: 250,
                itemWidth: 190,
                itemCount: open.length,
                itemBuilder: (context, i) => PhotoCard(
                  onTap: () => context.go('/venues/${open[i].code}'),
                  child: VenueArt(
                    venue: open[i],
                    media: media,
                    child: OverlayCaption(
                      eyebrow: open[i].city,
                      eyebrowColor: Color.lerp(open[i].accent, Colors.white, 0.35),
                      title: open[i].name.replaceFirst('Enish ', ''),
                    ),
                  ),
                ),
              ),
              PhotoStrip(
                eyebrow: 'Watch',
                title: 'Enish films',
                height: 220,
                itemWidth: 150,
                itemCount: films.length.clamp(0, 12),
                itemBuilder: (context, i) => FilmTile(
                  item: films[i],
                  color: all
                          .where((v) => v.code == films[i].venueCode)
                          .firstOrNull
                          ?.accent ??
                      EnishColors.oxblood,
                ),
              ),
              PhotoStrip(
                eyebrow: 'Made to be shared',
                title: 'From the kitchen',
                height: 180,
                itemWidth: 160,
                itemCount: food.length.clamp(0, 16),
                itemBuilder: (context, i) => CaptionedPhoto(item: food[i]),
              ),
              PhotoStrip(
                eyebrow: 'Music, nights & culture',
                title: "What's on",
                height: 240,
                itemWidth: 180,
                itemCount: listed.length + events.length.clamp(0, 12),
                itemBuilder: (context, i) => i < listed.length
                    ? EventCard(
                        event: listed[i],
                        venue: all
                            .where((v) => v.code == listed[i].venueCode)
                            .firstOrNull,
                      )
                    : PhotoCard(
                        onTap: () => showPhoto(context, events[i - listed.length]),
                        child: EnishPhoto(
                            url: events[i - listed.length].url,
                            alignment: Alignment.topCenter),
                      ),
              ),
              if (events.isNotEmpty || listed.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      EnishSpace.md, EnishSpace.sm, EnishSpace.md, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => context.go('/whats-on'),
                      child: const Text('SEE ALL EVENTS', style: EnishText.eyebrow),
                    ),
                  ),
                ),
              PhotoStrip(
                eyebrow: 'Designed moments',
                title: 'Experiences',
                height: 200,
                itemWidth: 280,
                itemCount: experiences.length,
                itemBuilder: (context, i) => PhotoCard(
                  onTap: () => showPhoto(context, experiences[i]),
                  child: EnishPhoto(url: experiences[i].url),
                ),
              ),
              _InsiderBanner(
                photo: experiences.isNotEmpty ? experiences.first : null,
              ),
              const SizedBox(height: EnishSpace.xl),
            ],
          );
        },
      ),
    );
  }
}

/// Full-bleed, auto-advancing carousel at the top of Home.
class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel({required this.media});

  final MediaLibrary media;

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  List<MediaItem> get _slides => widget.media.heroes;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(_HeroCarousel old) {
    super.didUpdateWidget(old);
    if (old.media.items.length != widget.media.items.length) _restart();
  }

  void _restart() {
    _timer?.cancel();
    if (_slides.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % _slides.length;
      _controller.animateToPage(next,
          duration: const Duration(milliseconds: 800), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _eyebrow(MediaItem m) => switch (m.category) {
        'food' => 'From the kitchen',
        'happening' => 'Nights at Enish',
        'experience' => 'Enish experiences',
        'venue' => 'Our places',
        _ => 'Enish',
      };

  @override
  Widget build(BuildContext context) {
    final slides = _slides;
    final height = MediaQuery.sizeOf(context).height * 0.62;

    return SizedBox(
      height: height.clamp(380.0, 560.0),
      child: Stack(fit: StackFit.expand, children: [
        if (slides.isEmpty)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF801500), Color(0xFF3A1208), EnishColors.background],
              ),
            ),
          )
        else
          PageView.builder(
            controller: _controller,
            itemCount: slides.length,
            onPageChanged: (p) => setState(() => _page = p),
            itemBuilder: (context, i) => Stack(fit: StackFit.expand, children: [
              EnishPhoto(url: slides[i].url),
              const PhotoScrim(strength: 0.9),
              Padding(
                padding: const EdgeInsets.only(bottom: 72),
                child: OverlayCaption(
                  eyebrow: _eyebrow(slides[i]),
                  title: slides[i].title,
                  titleSize: 22,
                ),
              ),
            ]),
          ),
        // Brand mark over the top of the carousel.
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(top: EnishSpace.md),
              child: Text(
                'ENISH',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                  color: EnishColors.cream,
                  shadows: [Shadow(blurRadius: 16)],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: EnishSpace.md,
          right: EnishSpace.md,
          bottom: EnishSpace.md,
          child: Row(children: [
            Expanded(
              child: EnishButton(
                label: 'Book a table',
                onPressed: () => context.go('/venues'),
              ),
            ),
            const SizedBox(width: EnishSpace.sm),
            if (slides.length > 1)
              Row(
                children: [
                  for (var i = 0; i < slides.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page ? EnishColors.gold : EnishColors.cream.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
          ]),
        ),
      ]),
    );
  }
}

class _YourEnish extends StatelessWidget {
  const _YourEnish({required this.venue, required this.media});

  final Venue venue;
  final MediaLibrary media;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          EnishSpace.md, EnishSpace.lg, EnishSpace.md, 0),
      child: SizedBox(
        height: 220,
        child: PhotoCard(
          radius: 18,
          onTap: () => context.go('/venues/${venue.code}'),
          child: VenueArt(
            venue: venue,
            media: media,
            child: Padding(
              padding: const EdgeInsets.all(EnishSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YOUR ENISH',
                      style: EnishText.eyebrow.copyWith(
                          color: Color.lerp(venue.accent, Colors.white, 0.4))),
                  const Spacer(),
                  Text(venue.name.toUpperCase(),
                      style: EnishText.title.copyWith(fontSize: 22)),
                  const SizedBox(height: EnishSpace.sm),
                  EnishButton(
                    label: 'Book a table',
                    color: venue.accent,
                    onPressed: () => bookVenue(context, venue),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChooseHome extends StatelessWidget {
  const _ChooseHome({required this.onChoose});

  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          EnishSpace.md, EnishSpace.lg, EnishSpace.md, 0),
      child: Container(
        padding: const EdgeInsets.all(EnishSpace.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF801500), Color(0xFFC9A227)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('YOUR ENISH',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w700,
                    color: EnishColors.cream)),
            const SizedBox(height: EnishSpace.sm),
            const Text(
              'Choose the Enish you visit most and it will be waiting here '
              'every time you open the app.',
              style: TextStyle(fontSize: 15, height: 1.5, color: EnishColors.cream),
            ),
            const SizedBox(height: EnishSpace.md),
            EnishButton(
              label: 'Choose your Enish',
              color: EnishColors.background,
              onPressed: onChoose,
            ),
          ],
        ),
      ),
    );
  }
}

class _InsiderBanner extends StatelessWidget {
  const _InsiderBanner({required this.photo});

  final MediaItem? photo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          EnishSpace.md, EnishSpace.xl, EnishSpace.md, 0),
      child: SizedBox(
        height: 200,
        child: PhotoCard(
          radius: 18,
          onTap: () => context.go('/insider'),
          child: Stack(fit: StackFit.expand, children: [
            if (photo != null) EnishPhoto(url: photo!.url),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    EnishColors.oxblood.withValues(alpha: 0.95),
                    EnishColors.oxblood.withValues(alpha: 0.2),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(EnishSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('MEMBERS ONLY',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 2.2,
                          fontWeight: FontWeight.w700,
                          color: EnishColors.gold)),
                  SizedBox(height: EnishSpace.sm),
                  Text('ENISH INSIDER', style: EnishText.display),
                  SizedBox(height: EnishSpace.sm),
                  SizedBox(
                    width: 220,
                    child: Text(
                      'Private offers, giveaways and first word on what is next.',
                      style: TextStyle(color: EnishColors.cream, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
