-- Enish core schema: venues, menus, events, news, enquiries, staff roles, audit.
-- Phase 1 of the backend design. Membership, tickets, offers and giveaways follow in later migrations.

-- ---------------------------------------------------------------------------
-- Shared helpers
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Venues (the location registry, now owned by the app)
-- ---------------------------------------------------------------------------

create table public.venues (
  code            text primary key,
  name            text not null,
  region          text not null,
  country         text not null,
  city            text not null,
  status          text not null check (status in ('open', 'coming_soon', 'unknown')),
  confirmed       boolean not null default false,
  published       boolean not null default false,
  address         text,
  phone           text,
  hours           text,
  latitude        double precision,
  longitude       double precision,
  booking_system  text,
  booking_url     text,
  events_email    text,
  notes           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create trigger venues_updated_at before update on public.venues
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Staff roles
-- ---------------------------------------------------------------------------

create table public.staff_roles (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  venue_code  text references public.venues (code) on delete cascade,
  role        text not null check (role in ('group_admin', 'venue_manager', 'venue_editor')),
  created_at  timestamptz not null default now(),
  -- A group admin has venue_code null; venue roles must name a venue.
  constraint staff_roles_scope check (
    (role = 'group_admin' and venue_code is null) or
    (role <> 'group_admin' and venue_code is not null)
  ),
  constraint staff_roles_unique unique nulls not distinct (user_id, venue_code, role)
);

create index staff_roles_user_idx on public.staff_roles (user_id);

-- Security-definer helpers so RLS policies do not recurse into staff_roles.
create or replace function public.is_group_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.staff_roles
    where user_id = (select auth.uid())
      and role = 'group_admin'
  );
$$;

-- True for group admins, and for venue staff of the named venue.
-- A null venue code (group-wide content) is only editable by group admins.
create or replace function public.can_edit_venue(p_venue_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_group_admin()
    or (
      p_venue_code is not null
      and exists (
        select 1 from public.staff_roles
        where user_id = (select auth.uid())
          and venue_code = p_venue_code
      )
    );
$$;

-- ---------------------------------------------------------------------------
-- Menus (per venue; venue_code null = group-wide menu item)
-- ---------------------------------------------------------------------------

create table public.menu_sections (
  id          uuid primary key default gen_random_uuid(),
  venue_code  text references public.venues (code) on delete cascade,
  name        text not null,
  sort_order  integer not null default 0,
  status      text not null default 'draft' check (status in ('draft', 'published')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index menu_sections_venue_idx on public.menu_sections (venue_code);

create trigger menu_sections_updated_at before update on public.menu_sections
  for each row execute function public.set_updated_at();

create table public.menu_items (
  id            uuid primary key default gen_random_uuid(),
  section_id    uuid not null references public.menu_sections (id) on delete cascade,
  venue_code    text references public.venues (code) on delete cascade,
  name          text not null,
  description   text,
  price_pence   integer check (price_pence is null or price_pence >= 0),
  dietary_tags  text[] not null default '{}',
  available     boolean not null default true,
  sort_order    integer not null default 0,
  status        text not null default 'draft' check (status in ('draft', 'published')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index menu_items_section_idx on public.menu_items (section_id);
create index menu_items_venue_idx on public.menu_items (venue_code);

create trigger menu_items_updated_at before update on public.menu_items
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Events (per venue; venue_code null = group-wide event)
-- ---------------------------------------------------------------------------

create table public.events (
  id            uuid primary key default gen_random_uuid(),
  venue_code    text references public.venues (code) on delete cascade,
  title         text not null,
  description   text,
  starts_at     timestamptz not null,
  ends_at       timestamptz,
  price_pence   integer check (price_pence is null or price_pence >= 0),
  image_url     text,
  members_only  boolean not null default false,
  status        text not null default 'draft' check (status in ('draft', 'published', 'cancelled')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint events_end_after_start check (ends_at is null or ends_at > starts_at)
);

create index events_venue_start_idx on public.events (venue_code, starts_at);

create trigger events_updated_at before update on public.events
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- News feed
-- ---------------------------------------------------------------------------

create table public.news_posts (
  id            uuid primary key default gen_random_uuid(),
  venue_code    text references public.venues (code) on delete cascade,
  title         text not null,
  body          text,
  image_url     text,
  status        text not null default 'draft' check (status in ('draft', 'published')),
  published_at  timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index news_posts_venue_idx on public.news_posts (venue_code);

create trigger news_posts_updated_at before update on public.news_posts
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Event enquiries (written only by the enquiry Edge Function, service role)
-- ---------------------------------------------------------------------------

create table public.enquiries (
  id              uuid primary key default gen_random_uuid(),
  venue_code      text not null references public.venues (code),
  name            text not null,
  email           text not null,
  phone           text,
  event_type      text not null,
  preferred_date  text not null,
  guest_count     integer check (guest_count is null or guest_count > 0),
  message         text,
  status          text not null default 'new' check (status in ('new', 'routed', 'replied', 'closed')),
  created_at      timestamptz not null default now()
);

create index enquiries_venue_idx on public.enquiries (venue_code, created_at desc);

-- ---------------------------------------------------------------------------
-- Audit log (written by trigger, read by group admins)
-- ---------------------------------------------------------------------------

create table public.audit_log (
  id          bigint generated always as identity primary key,
  actor_id    uuid,
  action      text not null,
  table_name  text not null,
  row_key     text,
  detail      jsonb,
  created_at  timestamptz not null default now()
);

create index audit_log_created_idx on public.audit_log (created_at desc);

create or replace function public.audit_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  r jsonb := to_jsonb(coalesce(new, old));
begin
  insert into public.audit_log (actor_id, action, table_name, row_key, detail)
  values (
    (select auth.uid()),
    lower(tg_op),
    tg_table_name,
    coalesce(r ->> 'code', r ->> 'id'),
    case when tg_op = 'UPDATE' then jsonb_build_object('before', to_jsonb(old), 'after', to_jsonb(new))
         else r end
  );
  return coalesce(new, old);
end;
$$;

create trigger venues_audit after insert or update or delete on public.venues
  for each row execute function public.audit_row();
create trigger staff_roles_audit after insert or update or delete on public.staff_roles
  for each row execute function public.audit_row();
create trigger menu_items_audit after insert or update or delete on public.menu_items
  for each row execute function public.audit_row();
create trigger events_audit after insert or update or delete on public.events
  for each row execute function public.audit_row();
create trigger news_posts_audit after insert or update or delete on public.news_posts
  for each row execute function public.audit_row();

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.venues        enable row level security;
alter table public.staff_roles   enable row level security;
alter table public.menu_sections enable row level security;
alter table public.menu_items    enable row level security;
alter table public.events        enable row level security;
alter table public.news_posts    enable row level security;
alter table public.enquiries     enable row level security;
alter table public.audit_log     enable row level security;

-- Venues: guests read published venues; only group admins change the registry.
create policy venues_read_published on public.venues
  for select using (published or public.is_group_admin());
create policy venues_admin_write on public.venues
  for all using (public.is_group_admin()) with check (public.is_group_admin());

-- Staff roles: a user can see their own roles; group admins manage all.
create policy staff_roles_read_own on public.staff_roles
  for select using (user_id = (select auth.uid()) or public.is_group_admin());
create policy staff_roles_admin_write on public.staff_roles
  for all using (public.is_group_admin()) with check (public.is_group_admin());

-- Menus: guests read published rows; venue staff read and write their venue.
create policy menu_sections_read on public.menu_sections
  for select using (status = 'published' or public.can_edit_venue(venue_code));
create policy menu_sections_write on public.menu_sections
  for all using (public.can_edit_venue(venue_code))
  with check (public.can_edit_venue(venue_code));

create policy menu_items_read on public.menu_items
  for select using (status = 'published' or public.can_edit_venue(venue_code));
create policy menu_items_write on public.menu_items
  for all using (public.can_edit_venue(venue_code))
  with check (public.can_edit_venue(venue_code));

-- Events: guests read published, non-member-only events. Member-only events
-- are added to this policy when membership is built.
create policy events_read on public.events
  for select using (
    (status = 'published' and not members_only) or public.can_edit_venue(venue_code)
  );
create policy events_write on public.events
  for all using (public.can_edit_venue(venue_code))
  with check (public.can_edit_venue(venue_code));

create policy news_posts_read on public.news_posts
  for select using (status = 'published' or public.can_edit_venue(venue_code));
create policy news_posts_write on public.news_posts
  for all using (public.can_edit_venue(venue_code))
  with check (public.can_edit_venue(venue_code));

-- Enquiries: staff of the venue read them. No anonymous or client writes;
-- the Edge Function uses the service role.
create policy enquiries_read on public.enquiries
  for select using (public.can_edit_venue(venue_code));
create policy enquiries_staff_update on public.enquiries
  for update using (public.can_edit_venue(venue_code))
  with check (public.can_edit_venue(venue_code));

-- Audit log: group admins only.
create policy audit_log_admin_read on public.audit_log
  for select using (public.is_group_admin());

-- Lock the security-definer helpers to signed-in use only.
revoke execute on function public.is_group_admin() from public, anon;
revoke execute on function public.can_edit_venue(text) from public, anon;
grant execute on function public.is_group_admin() to authenticated;
grant execute on function public.can_edit_venue(text) to authenticated;

-- Trigger functions are never called through the API.
revoke execute on function public.audit_row() from public, anon, authenticated;

-- Table privileges. Row-level security decides which rows; these grants decide
-- whether the role may touch the table at all. Without them PostgREST returns 42501.
-- Supabase's default privileges grant everything (including TRUNCATE, which RLS
-- does not cover), so remove them first, then grant only what each role needs.
alter default privileges in schema public revoke all on tables from anon, authenticated;
revoke all on all tables in schema public from anon, authenticated;
grant select on public.venues, public.menu_sections, public.menu_items,
  public.events, public.news_posts to anon;
grant select, insert, update, delete on public.venues, public.staff_roles,
  public.menu_sections, public.menu_items, public.events, public.news_posts
  to authenticated;
grant select, update on public.enquiries to authenticated;
grant select on public.audit_log to authenticated;
