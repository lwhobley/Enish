# Enish

The Enish app: every Enish venue, its events, photos and Insider perks in one
place, plus a staff area where venue teams publish their own events.

Built with Flutter (iOS, Android, web) on a Supabase backend.

## Project layout

| Path | What it holds |
| --- | --- |
| `lib/main.dart` | App start-up, routes and the bottom navigation |
| `lib/config.dart` | Supabase URL and publishable key |
| `lib/data/` | Reading and writing venues, events and media |
| `lib/screens/` | Guest screens (home, venues, what's on, Insider) and `staff.dart` |
| `lib/brand/` | Colours, type and shared visual components |
| `supabase/migrations/` | Database schema, row-level security and storage rules |
| `supabase/seed/venues.sql` | The venue registry |
| `supabase/functions/` | Edge Functions: `submit-enquiry`, plus two one-off importers (now disabled) |
| `test/widget_test.dart` | Unit and widget tests |
| `codemagic.yaml` | iOS build and TestFlight upload |

## Running the app

```bash
flutter pub get
flutter run
```

```bash
flutter test
```

The app talks to the Supabase project named in `lib/config.dart`
(currently the `enish-dev` project). Point it at the production project
before release. The publishable key is safe to ship: row-level security on
the database decides what each person can read and write.

## Backend

Apply migrations in filename order (Supabase CLI `supabase db push`, or the
SQL editor), then load `supabase/seed/venues.sql`.

Two places name the project and must change together when moving to another
project: `lib/config.dart` and `public.media_public_base()` in
`supabase/migrations/20261111000300_media_autoregister.sql`.

### Who can do what

- **Guests** read published venues, menus, news, media and public events.
  Members-only events stay hidden until Insider membership is built.
- **Venue staff** (`venue_manager`, `venue_editor`) manage their own venue's
  events, menus and news. Both roles currently have the same powers.
- **Group admins** manage every venue, group-wide content and the team.
  The database always keeps at least one group admin.

Staff logins are created by head office in the Supabase dashboard
(Authentication › Users › Add user); a group admin then gives the account
access from the app's Team screen.

### Media and posters

- Files dropped into the `media` storage bucket appear in the app
  automatically. Folders: `intro/<file>`, `<category>/<file>` or
  `<category>/<venue-code>/<file>`, where the category is one of venue, food,
  drink, event, happening, experience, brand or intro.
- Event posters go to the `posters` bucket under `<venue-code>/` (or
  `group/` for group-wide events). Staff can only write their own venues.

### Event times

Staff enter event times as the venue's own wall-clock time. The database
keeps that (`starts_local`, `ends_local`) and works out the real instant
(`starts_at`, `ends_at`) from the venue's time zone, so listings sort
correctly across London, Dubai, Houston and Africa.

### Enquiries and saved preferences

- Event enquiries from a venue page go to the `submit-enquiry` Edge Function,
  which saves them to the `enquiries` table with the service role. Venue staff
  can read their venue's enquiries.
- A guest's chosen home venue is saved on the device (shared_preferences)
  until guest accounts exist.

## Releasing

Every push to `main` makes Codemagic run the tests, build the iOS app and
upload it to TestFlight (see `codemagic.yaml`).

## Not built yet

- Insider membership and billing.
- Guest accounts and booking history.
- Ongoing media import from the website or Instagram.
