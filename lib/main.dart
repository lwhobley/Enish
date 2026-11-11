import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'brand/brand.dart';
import 'config.dart';
import 'screens/home.dart';
import 'screens/intro.dart';
import 'screens/member.dart';
import 'screens/venues.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: EnishConfig.supabaseUrl,
    publishableKey: EnishConfig.supabasePublishableKey,
  );
  runApp(const ProviderScope(child: EnishApp()));
}

final _router = GoRouter(
  initialLocation: '/intro',
  routes: [
    GoRoute(path: '/intro', builder: (_, _) => const IntroScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _Shell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/venues',
            builder: (_, _) => const VenuesScreen(),
            routes: [
              GoRoute(
                path: ':code',
                builder: (_, s) => VenueScreen(code: s.pathParameters['code']!),
                routes: [
                  GoRoute(
                    path: 'enquire',
                    builder: (_, s) =>
                        EnquiryScreen(code: s.pathParameters['code']!),
                  ),
                ],
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/whats-on', builder: (_, _) => const WhatsOnScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/insider', builder: (_, _) => const InsiderScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
        ]),
      ],
    ),
  ],
);

class EnishApp extends StatelessWidget {
  const EnishApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Enish',
      debugShowCheckedModeBanner: false,
      theme: enishTheme(),
      routerConfig: _router,
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: EnishColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: 'HOME'),
            NavigationDestination(icon: Icon(Icons.place_outlined), label: 'VENUES'),
            NavigationDestination(icon: Icon(Icons.event_outlined), label: "WHAT'S ON"),
            NavigationDestination(icon: Icon(Icons.star_outline), label: 'INSIDER'),
            NavigationDestination(icon: Icon(Icons.person_outline), label: 'ACCOUNT'),
          ],
        ),
      ),
    );
  }
}
