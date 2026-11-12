-- Staff event management: venue-local times, a poster bucket venue staff can
-- write to, and group-admin functions for managing the team by email.

-- ---------------------------------------------------------------------------
-- Venue time zones. Staff type event times as the venue's wall-clock time;
-- the database works out the real instant, so sorting and "upcoming" are
-- correct across London, Dubai, Houston and Africa.
-- ---------------------------------------------------------------------------

alter table public.venues add column time_zone text not null default 'Europe/London';

update public.venues set time_zone = case
  when region = 'UAE' then 'Asia/Dubai'
  when code = 'houston' then 'America/Chicago'
  when code = 'accra' then 'Africa/Accra'
  when code = 'nairobi' then 'Africa/Nairobi'
  else 'Europe/London'
end;

create or replace function public.check_time_zone()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (select 1 from pg_catalog.pg_timezone_names where name = new.time_zone) then
    raise exception 'Unknown time zone: %', new.time_zone;
  end if;
  return new;
end;
$$;

create trigger venues_time_zone before insert or update of time_zone on public.venues
  for each row execute function public.check_time_zone();

-- ---------------------------------------------------------------------------
-- Events keep the wall-clock time staff entered; starts_at/ends_at follow.
-- Group-wide events (no venue) use London time.
-- ---------------------------------------------------------------------------

alter table public.events
  add column starts_local timestamp,
  add column ends_local timestamp;

create or replace function public.events_resolve_times()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  tz text := coalesce(
    (select v.time_zone from public.venues v where v.code = new.venue_code),
    'Europe/London');
begin
  if new.starts_local is null then
    raise exception 'starts_local is required';
  end if;
  new.starts_at := new.starts_local at time zone tz;
  new.ends_at := case when new.ends_local is null then null
                      else new.ends_local at time zone tz end;
  return new;
end;
$$;

create trigger events_resolve_times before insert or update on public.events
  for each row execute function public.events_resolve_times();

create index events_status_start_idx on public.events (status, starts_at);

revoke execute on function public.check_time_zone() from public, anon, authenticated;
revoke execute on function public.events_resolve_times() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Event posters: public images. Paths are <venue-code>/<file> (or
-- group/<file> for group-wide events); staff may only write their venues.
-- Separate from the media bucket so posters never appear in photo strips.
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('posters', 'posters', true, 10485760,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy posters_staff_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'posters'
              and public.can_edit_venue((storage.foldername(name))[1]));
create policy posters_staff_update on storage.objects
  for update to authenticated
  using (bucket_id = 'posters'
         and public.can_edit_venue((storage.foldername(name))[1]));
create policy posters_staff_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'posters'
         and public.can_edit_venue((storage.foldername(name))[1]));

-- ---------------------------------------------------------------------------
-- Team management for group admins. Accounts are created in the Supabase
-- dashboard; these functions attach roles by email.
-- ---------------------------------------------------------------------------

create or replace function public.staff_directory()
returns table (id uuid, email text, venue_code text, role text, created_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, u.email::text, r.venue_code, r.role, r.created_at
  from public.staff_roles r
  join auth.users u on u.id = r.user_id
  where public.is_group_admin()
  order by u.email, r.venue_code nulls first;
$$;

create or replace function public.grant_staff_role(
  p_email text, p_venue_code text, p_role text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid;
  v_id uuid;
begin
  if not public.is_group_admin() then
    raise exception 'Only group admins can manage the team' using errcode = '42501';
  end if;
  select u.id into v_user from auth.users u where lower(u.email) = lower(trim(p_email));
  if v_user is null then
    raise exception 'No account for %. Create it in Supabase first.', p_email;
  end if;
  insert into public.staff_roles (user_id, venue_code, role)
  values (v_user, case when p_role = 'group_admin' then null else p_venue_code end, p_role)
  on conflict on constraint staff_roles_unique do nothing
  returning id into v_id;
  return v_id;
end;
$$;

revoke execute on function public.staff_directory() from public, anon;
revoke execute on function public.grant_staff_role(text, text, text) from public, anon;
grant execute on function public.staff_directory() to authenticated;
grant execute on function public.grant_staff_role(text, text, text) to authenticated;
