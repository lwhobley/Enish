import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/locations.dart';
import '../data/media.dart';
import 'brand.dart';

/// A cached network photo with a soft fade-in and a branded fallback.
class EnishPhoto extends StatelessWidget {
  const EnishPhoto({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.placeholderColor = EnishColors.surface,
  });

  final String url;
  final BoxFit fit;
  final Alignment alignment;

  /// Transparent for overlays (illustrations) so the colour beneath shows
  /// while the image loads.
  final Color placeholderColor;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: const Duration(milliseconds: 350),
      placeholder: (_, _) => ColoredBox(color: placeholderColor),
      errorWidget: (_, _, _) => ColoredBox(
        color: placeholderColor,
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined,
              color: EnishColors.border),
        ),
      ),
    );
  }
}

/// Dark wash so text stays readable over any photo.
class PhotoScrim extends StatelessWidget {
  const PhotoScrim({super.key, this.strength = 0.85});

  final double strength;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.35, 1],
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: strength),
          ],
        ),
      ),
    );
  }
}

/// The face of a venue: its photo when there is one, otherwise its line
/// illustration over the venue's own colour.
class VenueArt extends StatelessWidget {
  const VenueArt({
    super.key,
    required this.venue,
    required this.media,
    this.child,
    this.dim = false,
  });

  final Venue venue;
  final MediaLibrary media;
  final Widget? child;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final photo = media.venuePhoto(venue.code);
    final art = media.venueArt(venue.code);
    final accent = venue.accent;

    final Widget base;
    if (photo != null) {
      base = Stack(fit: StackFit.expand, children: [
        EnishPhoto(url: photo.url),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent.withValues(alpha: 0.25), Colors.transparent],
            ),
          ),
        ),
      ]);
    } else {
      base = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color.lerp(accent, Colors.white, 0.08)!,
              accent,
              Color.lerp(accent, Colors.black, 0.55)!,
            ],
          ),
        ),
        child: art == null
            ? Padding(
                padding: const EdgeInsets.all(EnishSpace.md),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      venue.city.toUpperCase(),
                      maxLines: 1,
                      style: EnishText.display.copyWith(
                        fontSize: 44,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 0),
                child: EnishPhoto(
                  url: art.url,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  placeholderColor: Colors.transparent,
                ),
              ),
      );
    }

    return Stack(fit: StackFit.expand, children: [
      if (dim)
        ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.33, 0.33, 0.33, 0, 0,
            0.33, 0.33, 0.33, 0, 0,
            0.33, 0.33, 0.33, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: base,
        )
      else
        base,
      const PhotoScrim(strength: 0.75),
      ?child,
    ]);
  }
}

/// Title block laid over a photo.
class OverlayCaption extends StatelessWidget {
  const OverlayCaption({
    super.key,
    required this.title,
    this.eyebrow,
    this.eyebrowColor,
    this.titleSize = 16,
  });

  final String title;
  final String? eyebrow;
  final Color? eyebrowColor;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(EnishSpace.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eyebrow != null) ...[
              Text(
                eyebrow!.toUpperCase(),
                style: EnishText.eyebrow.copyWith(
                  color: eyebrowColor ?? EnishColors.gold,
                ),
              ),
              const SizedBox(height: EnishSpace.xs),
            ],
            Text(
              title.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: EnishText.title.copyWith(
                fontSize: titleSize,
                shadows: const [Shadow(blurRadius: 12)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded, clipped card used for every photo tile.
class PhotoCard extends StatelessWidget {
  const PhotoCard({
    super.key,
    required this.child,
    this.onTap,
    this.radius = 14,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Material(
        color: EnishColors.surface,
        child: InkWell(
          onTap: onTap,
          child: child,
        ),
      ),
    );
  }
}

/// Section heading followed by a horizontally scrolling row of tiles.
class PhotoStrip extends StatelessWidget {
  const PhotoStrip({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    this.eyebrow,
    this.height = 200,
    this.itemWidth = 160,
  });

  final String title;
  final String? eyebrow;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double height;
  final double itemWidth;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EnishSectionHeader(title: title, eyebrow: eyebrow),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: EnishSpace.md),
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(width: EnishSpace.sm + 4),
            itemBuilder: (context, i) =>
                SizedBox(width: itemWidth, child: itemBuilder(context, i)),
          ),
        ),
      ],
    );
  }
}

/// A food or event photo with its title underneath.
class CaptionedPhoto extends StatelessWidget {
  const CaptionedPhoto({super.key, required this.item, this.onTap});

  final MediaItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PhotoCard(
      onTap: onTap ?? () => showPhoto(context, item),
      child: Stack(fit: StackFit.expand, children: [
        EnishPhoto(url: item.url),
        const PhotoScrim(strength: 0.8),
        OverlayCaption(title: item.title, titleSize: 12),
      ]),
    );
  }
}

/// A silent, looping, full-bleed clip. Shows [placeholder] until the first
/// frame is ready (or for good if the clip cannot play).
class LoopingVideo extends StatefulWidget {
  const LoopingVideo({
    super.key,
    required this.url,
    this.placeholder = const ColoredBox(color: Colors.black),
  });

  final String url;
  final Widget placeholder;

  @override
  State<LoopingVideo> createState() => _LoopingVideoState();
}

class _LoopingVideoState extends State<LoopingVideo> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      // Browsers and phones only autoplay muted video.
      ..setVolume(0);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _controller.play();
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _controller.value;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      // Fill the whole area so the clip covers edge to edge.
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, ?current],
      ),
      child: !v.isInitialized || v.hasError
          ? KeyedSubtree(key: const ValueKey('wait'), child: widget.placeholder)
          : FittedBox(
              key: const ValueKey('play'),
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: v.size.width,
                height: v.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
    );
  }
}

/// A clip in a strip: the venue's colour, a play button and the title.
class FilmTile extends StatelessWidget {
  const FilmTile({super.key, required this.item, required this.color});

  final MediaItem item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PhotoCard(
      onTap: () => showFilm(context, item),
      child: Stack(fit: StackFit.expand, children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [color, Color.lerp(color, Colors.black, 0.6)!],
            ),
          ),
        ),
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.35),
              border: Border.all(color: EnishColors.cream, width: 1.5),
            ),
            child: const Icon(Icons.play_arrow_rounded,
                color: EnishColors.cream, size: 34),
          ),
        ),
        OverlayCaption(title: item.title, titleSize: 12),
      ]),
    );
  }
}

/// Full-screen player with sound. Tap to pause or resume.
Future<void> showFilm(BuildContext context, MediaItem item) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    builder: (context) => _FilmPlayer(item: item),
  );
}

class _FilmPlayer extends StatefulWidget {
  const _FilmPlayer({required this.item});

  final MediaItem item;

  @override
  State<_FilmPlayer> createState() => _FilmPlayerState();
}

class _FilmPlayerState extends State<_FilmPlayer> {
  late final VideoPlayerController _c;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.item.url))
      ..setLooping(true)
      ..addListener(_refresh);
    _c.initialize().then((_) => _c.play(), onError: (_) {});
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _c.value;
    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          onTap: () => v.isPlaying ? _c.pause() : _c.play(),
          child: Center(
            child: v.hasError
                ? const Text('This clip could not be played.',
                    style: EnishText.body)
                : !v.isInitialized
                    ? const CircularProgressIndicator()
                    : AspectRatio(
                        aspectRatio: v.aspectRatio,
                        child: Stack(alignment: Alignment.center, children: [
                          VideoPlayer(_c),
                          if (!v.isPlaying)
                            const Icon(Icons.play_arrow_rounded,
                                color: EnishColors.cream, size: 72),
                        ]),
                      ),
          ),
        ),
      ),
      if (v.isInitialized)
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: SafeArea(
            child: VideoProgressIndicator(
              _c,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: EnishColors.gold,
                backgroundColor: EnishColors.border,
              ),
            ),
          ),
        ),
      Positioned(
        top: 8,
        right: 8,
        child: SafeArea(
          child: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close, color: EnishColors.cream),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    ]);
  }
}

/// Full-screen, zoomable view of a single photo or poster.
Future<void> showPhoto(BuildContext context, MediaItem item) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (context) => GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Stack(children: [
        Positioned.fill(
          child: InteractiveViewer(
            child: EnishPhoto(url: item.url, fit: BoxFit.contain),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: SafeArea(
            child: IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close, color: EnishColors.cream),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ]),
    ),
  );
}
