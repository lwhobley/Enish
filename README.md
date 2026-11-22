# Enish

Multi-venue companion app for the Enish restaurant group (UK, UAE, USA, Africa).

Guests discover venues, book tables, see what's on, and (soon) join Insider membership. Venue teams manage events from the staff area.

## Stack

- **Client**: Flutter (Riverpod, go_router)
- **Backend**: Supabase (Postgres + RLS, Auth, Storage, Edge Functions)
- **CI**: Codemagic → TestFlight

## Local setup

```bash
flutter pub get
# Point lib/config.dart at your Supabase project (or use --dart-define)
flutter run
```

## Architecture notes

- Venues, menus, events, media and staff roles live in Postgres with row-level security.
- Guests only see published content. Staff roles (group_admin / venue_manager / venue_editor) control writes.
- Event times are entered as venue wall-clock time; the database converts to real instants using the venue's time zone.
- Home venue preference is persisted locally with shared_preferences (will sync to account later).
- Enquiries are submitted via the `submit-enquiry` Edge Function (service-role insert).

## Staff

Accounts are created in the Supabase dashboard. Group admins can then grant venue roles via the Team screen (or the `grant_staff_role` RPC).

## Next

- Full Insider membership + billing
- Media import from website / Instagram
- Guest accounts and booking history
