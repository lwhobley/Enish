import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../brand/brand.dart';
import '../brand/visuals.dart';
import '../data/locations.dart';
import '../data/events.dart';
import '../data/media.dart';
import 'event_card.dart';

/// Every event across the group, as a wall of posters filterable by venue.
class WhatsOnScreen extends ConsumerStatefulWidget {
  const WhatsOnScreen({super.key});

  @override
  ConsumerState<WhatsOnScreen> createState() => _WhatsOnScreenState();
}

class _WhatsOnScreenState extends ConsumerState<WhatsOnScreen> {
  String? _venue;

  @override
  Widget build(BuildContext context) {
    final media = ref.watch(mediaProvider).value ?? MediaLibrary.empty;
    final venues = ref.watch(venuesProvider).value ?? const <Venue>[];
    final byCode = {for (final v in venues) v.code: v};

    final listedAsync = ref.watch(upcomingEventsProvider);
    final listed = listedAsync.value ?? const <EnishEvent>[];
    final loading = listedAsync.isLoading || ref.watch(mediaProvider).isLoading;
    final all = media.events;
    final codes = {
      for (final e in all) ?e.venueCode,
      for (final e in listed) ?e.venueCode,
    }.toList()
      ..sort();
    final shown = _venue == null ? all : all.where((e) => e.venueCode == _venue).toList();
    final shownListed = _venue == null ? listed : listed.at(_venue!);

    return Scaffold(
      appBar: AppBar(title: const Text("WHAT'S ON")),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: EnishSpace.md, vertical: EnishSpace.sm),
              children: [
                _Chip(
                  label: 'All venues',
                  color: EnishColors.gold,
                  selected: _venue == null,
                  onTap: () => setState(() => _venue = null),
                ),
                for (final c in codes)
                  _Chip(
                    label: byCode[c]?.name.replaceFirst('Enish ', '') ?? c,
                    color: byCode[c]?.accent ?? EnishColors.gold,
                    selected: _venue == c,
                    onTap: () => setState(() => _venue = c),
                  ),
              ],
            ),
          ),
        ),
        if (shownListed.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: EnishSectionHeader(eyebrow: 'Dates for the diary', title: 'Coming up'),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: EnishSpace.md),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                childAspectRatio: 0.72,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: shownListed.length,
              itemBuilder: (context, i) => EventCard(
                event: shownListed[i],
                venue: byCode[shownListed[i].venueCode],
              ),
            ),
          ),
          if (shown.isNotEmpty)
            const SliverToBoxAdapter(
              child: EnishSectionHeader(eyebrow: 'Posters', title: 'From the venues'),
            ),
        ],
        if (shown.isEmpty && shownListed.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: EnishSpace.md),
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : const EnishComingSoon(message: 'No events listed yet.'),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(EnishSpace.md),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                childAspectRatio: 0.72,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final e = shown[i];
                final v = byCode[e.venueCode];
                return PhotoCard(
                  onTap: () => showPhoto(context, e),
                  child: Stack(fit: StackFit.expand, children: [
                    EnishPhoto(url: e.url, alignment: Alignment.topCenter),
                    if (v != null)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: v.accent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            v.city.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ]),
                );
              },
            ),
          ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: EnishSpace.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}

class InsiderScreen extends ConsumerWidget {
  const InsiderScreen({super.key});

  static const _perks = [
    (Icons.badge_outlined, 'Member card', 'One card recognised at every Enish.'),
    (Icons.local_offer_outlined, 'Offers', 'Member pricing and private discounts.'),
    (Icons.card_giftcard, 'Giveaways', 'Tables, tickets and experiences for members only.'),
    (Icons.campaign_outlined, 'First word', 'Openings, guest lists and events before anyone else.'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(mediaProvider).value ?? MediaLibrary.empty;
    final hero = media.experiences.isNotEmpty ? media.experiences.first : null;

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 340,
          backgroundColor: EnishColors.oxblood,
          flexibleSpace: FlexibleSpaceBar(
            title: const Text('ENISH INSIDER', style: EnishText.title),
            background: Stack(fit: StackFit.expand, children: [
              if (hero != null) EnishPhoto(url: hero.url),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      EnishColors.oxblood.withValues(alpha: 0.15),
                      EnishColors.oxblood.withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                EnishSpace.md, EnishSpace.lg, EnishSpace.md, EnishSpace.sm),
            child: Text(
              'A private membership for the people who make Enish what it is.',
              style: TextStyle(fontSize: 17, height: 1.5, color: EnishColors.cream),
            ),
          ),
        ),
        SliverList.list(children: [
          for (final (icon, title, body) in _perks)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: EnishSpace.md, vertical: EnishSpace.xs),
              child: Container(
                padding: const EdgeInsets.all(EnishSpace.md),
                decoration: BoxDecoration(
                  color: EnishColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [EnishColors.oxblood, EnishColors.gold],
                      ),
                    ),
                    child: Icon(icon, color: EnishColors.cream, size: 22),
                  ),
                  const SizedBox(width: EnishSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title.toUpperCase(), style: EnishText.label),
                        const SizedBox(height: 2),
                        Text(body, style: EnishText.body.copyWith(fontSize: 13)),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(EnishSpace.md),
            child: EnishButton(
              label: 'Become an Insider',
              // TODO(membership): open the subscription paywall. Billing is
              // not connected, so nothing can be purchased yet.
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Membership is not available yet.')),
              ),
            ),
          ),
          const SizedBox(height: EnishSpace.xl),
        ]),
      ]),
    );
  }
}

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final access = ref.watch(staffAccessProvider).value ?? StaffAccess.none;

    return Scaffold(
      appBar: AppBar(title: const Text('ACCOUNT')),
      body: ListView(
        children: [
          const EnishSectionHeader(title: 'Your account'),
          const EnishComingSoon(
            message: 'Sign-in, your bookings, notification settings and '
                'membership management appear here once accounts are '
                'connected.',
          ),
          const EnishSectionHeader(eyebrow: 'For venue teams', title: 'Staff'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: EnishSpace.md),
            child: session == null
                ? EnishButton(
                    label: 'Staff sign in',
                    primary: false,
                    icon: Icons.lock_outline,
                    onPressed: () => context.go('/account/sign-in'),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Signed in as ${session.user.email ?? ''}',
                          style: EnishText.body),
                      const SizedBox(height: EnishSpace.md),
                      if (access.isStaff) ...[
                        EnishButton(
                          label: 'Manage events',
                          icon: Icons.event_note_outlined,
                          onPressed: () => context.go('/account/staff'),
                        ),
                        const SizedBox(height: EnishSpace.sm),
                      ],
                      EnishButton(
                        label: 'Sign out',
                        primary: false,
                        onPressed: StaffApi.signOut,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: EnishSpace.xl),
        ],
      ),
    );
  }
}
