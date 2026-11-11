import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A photo, illustration or video held in the app's own `media` storage.
class MediaItem {
  const MediaItem({
    required this.kind,
    required this.category,
    required this.url,
    required this.storagePath,
    this.venueCode,
    this.title = '',
  });

  final String kind; // photo | illustration | video
  final String category; // venue | food | drink | event | happening | experience | brand | intro
  final String url;
  final String storagePath;
  final String? venueCode;
  final String title;

  bool get isVideo => kind == 'video';

  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
        kind: j['kind'] as String,
        category: j['category'] as String,
        url: j['public_url'] as String,
        storagePath: j['storage_path'] as String,
        venueCode: j['venue_code'] as String?,
        title: j['title'] as String? ?? '',
      );
}

/// Everything published, with the lookups the screens need.
class MediaLibrary {
  const MediaLibrary(this.items);

  static const empty = MediaLibrary([]);

  final List<MediaItem> items;

  /// Still images only; video is served through [films] and [introVideo].
  Iterable<MediaItem> _where(String category, {String? venue}) => items.where(
      (m) =>
          !m.isVideo &&
          m.category == category &&
          (venue == null || m.venueCode == venue));

  /// Uploaded clips (everything except the intro film), newest sort first.
  List<MediaItem> get films =>
      items.where((m) => m.isVideo && m.category != 'intro').toList();
  List<MediaItem> filmsAt(String venue) =>
      films.where((m) => m.venueCode == venue).toList();

  List<MediaItem> get food => _where('food').toList();
  List<MediaItem> get events => _where('event').toList();
  List<MediaItem> get happenings => _where('happening').toList();
  List<MediaItem> get experiences => _where('experience').toList();

  List<MediaItem> foodAt(String venue) => _where('food', venue: venue).toList();
  List<MediaItem> eventsAt(String venue) => _where('event', venue: venue).toList();

  MediaItem? venuePhoto(String venue) =>
      _where('venue', venue: venue).where((m) => m.kind == 'photo').firstOrNull;
  MediaItem? venueArt(String venue) => _where('venue', venue: venue)
      .where((m) => m.kind == 'illustration')
      .firstOrNull;

  MediaItem? brand(String name) =>
      items.where((m) => m.storagePath.startsWith('brand/$name')).firstOrNull;

  /// An intro video, once one is uploaded (or synced from Instagram).
  MediaItem? get introVideo =>
      items.where((m) => m.category == 'intro' && m.isVideo).firstOrNull;

  /// Photos for the opening sequence: venues, nights out, then the kitchen.
  List<MediaItem> get introPhotos => [
        ...items.where((m) => m.category == 'venue' && m.kind == 'photo'),
        ...happenings,
        ...items.where((m) => m.category == 'intro' && !m.isVideo),
        ...food.take(6),
        ...experiences.take(2),
      ];

  /// Lead images for the home carousel, mixing places, plates and nights.
  List<MediaItem> get heroes {
    final out = <MediaItem>[];
    final pools = [
      items.where((m) => m.category == 'venue' && m.kind == 'photo').toList(),
      food.take(4).toList(),
      happenings,
      experiences.take(2).toList(),
    ];
    for (var i = 0; out.length < 8; i++) {
      var added = false;
      for (final pool in pools) {
        if (i < pool.length) {
          out.add(pool[i]);
          added = true;
        }
      }
      if (!added) break;
    }
    return out;
  }
}

Future<MediaLibrary> fetchMedia() async {
  final rows = await Supabase.instance.client
      .from('media')
      .select('kind, category, public_url, storage_path, venue_code, title')
      .eq('status', 'published')
      .order('sort_order');
  return MediaLibrary([for (final r in rows) MediaItem.fromJson(r)]);
}

final mediaProvider = FutureProvider<MediaLibrary>((ref) => fetchMedia());
