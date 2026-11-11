import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../brand/brand.dart';
import '../brand/visuals.dart';
import '../data/media.dart';

/// Opening sequence. Plays the intro film when one is in storage; until then
/// it is a slow, cross-fading sequence of Enish photography.
class IntroScreen extends ConsumerWidget {
  const IntroScreen({super.key});

  static const greetings = [
    'E KU ABO', 'NNO', 'BARKA DA ZUWA', 'KARIBU', 'AKWAABA',
    'SIYAKWAMUKELA', 'AHLAN WA SAHLAN', 'YOU ARE WELCOME',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(mediaProvider).value ?? MediaLibrary.empty;
    final video = media.introVideo;
    final logo = media.brand('logo');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        if (video != null)
          LoopingVideo(
            url: video.url,
            // Photos carry the opening until the film is ready to play.
            placeholder: _Slideshow(photos: media.introPhotos),
          )
        else
          _Slideshow(photos: media.introPhotos),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.3, 0.6, 1],
              colors: [
                Color(0xAA000000), Color(0x22000000),
                Color(0x44000000), Color(0xEE000000),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(EnishSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: () => context.go('/'),
                    child: const Text('SKIP', style: EnishText.label),
                  ),
                ),
                const Spacer(),
                if (logo != null)
                  SizedBox(
                    height: 64,
                    child: EnishPhoto(url: logo.url, fit: BoxFit.contain),
                  )
                else
                  const Text('ENISH',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 10,
                        color: EnishColors.cream,
                      )),
                const SizedBox(height: EnishSpace.md),
                const Text(
                  'GOOD FOOD, GOOD MOOD',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w600,
                    color: EnishColors.gold,
                  ),
                ),
                const SizedBox(height: EnishSpace.lg),
                const _Greetings(words: greetings),
                const SizedBox(height: EnishSpace.xl),
                EnishButton(label: 'Enter Enish', onPressed: () => context.go('/')),
                const SizedBox(height: EnishSpace.md),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

/// Cross-fades through photos, each one slowly pushing in.
class _Slideshow extends StatefulWidget {
  const _Slideshow({required this.photos});

  final List<MediaItem> photos;

  @override
  State<_Slideshow> createState() => _SlideshowState();
}

class _SlideshowState extends State<_Slideshow> {
  static const _hold = Duration(milliseconds: 4200);
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(_Slideshow old) {
    super.didUpdateWidget(old);
    if (old.photos.length != widget.photos.length) _start();
  }

  void _start() {
    _timer?.cancel();
    if (widget.photos.length < 2) return;
    _timer = Timer.periodic(_hold, (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % widget.photos.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF801500), Color(0xFF3A1208), Colors.black],
          ),
        ),
      );
    }
    final photo = widget.photos[_index % widget.photos.length];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1200),
      child: _KenBurns(
        key: ValueKey(photo.url),
        url: photo.url,
        // Alternate the drift direction for movement.
        reverse: _index.isOdd,
      ),
    );
  }
}

class _KenBurns extends StatelessWidget {
  const _KenBurns({super.key, required this.url, required this.reverse});

  final String url;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 5600),
      curve: Curves.easeOut,
      builder: (context, t, child) => Transform.scale(
        scale: 1.04 + 0.12 * t,
        alignment: reverse ? Alignment.topLeft : Alignment.bottomRight,
        child: child,
      ),
      child: EnishPhoto(url: url),
    );
  }
}

/// The site's welcome in many languages, one word at a time.
class _Greetings extends StatefulWidget {
  const _Greetings({required this.words});

  final List<String> words;

  @override
  State<_Greetings> createState() => _GreetingsState();
}

class _GreetingsState extends State<_Greetings> {
  Timer? _timer;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (mounted) setState(() => _i = (_i + 1) % widget.words.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: Text(
          widget.words[_i],
          key: ValueKey(_i),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            letterSpacing: 3,
            color: EnishColors.cream,
            fontWeight: FontWeight.w300,
          ),
        ),
      ),
    );
  }
}
