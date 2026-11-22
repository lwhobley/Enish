-- Fixes from the repository review: event times, team lock-out, menu ownership.

-- ---------------------------------------------------------------------------
-- 1. Event times read the venue's time zone whatever the editor's own access
--    to the venues table. Before, staff of an unpublished venue could not see
--    their venue row and silently got London time.
-- ---------------------------------------------------------------------------

create or replace function public.events_resolve_times()
returns trigger
language plpgsql
security definer
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

revoke execute on function public.events_resolve_times() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Events written before starts_local existed could not be saved again
--    (the trigger above requires it). Fill it in from the real instant and
--    the venue's zone, so the time shown is unchanged.
-- ---------------------------------------------------------------------------

update public.events e
set starts_local = e.starts_at at time zone z.zone,
    ends_local = case when e.ends_at is null then null
                      else e.ends_at at time zone z.zone end
from (
  select ev.id, coalesce(v.time_zone, 'Europe/London') as zone
  from public.events ev
  left join public.venues v on v.code = ev.venue_code
) z
where z.id = e.id
  and e.starts_local is null;

-- ---------------------------------------------------------------------------
-- 3. Correcting a venue's time zone re-times its events: the wall-clock
--    times staff typed stay, the real instants follow.
-- ---------------------------------------------------------------------------

create or replace function public.venues_retime_events()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Touching starts_local re-runs events_resolve_times for each row.
  update public.events set starts_local = starts_local where venue_code = new.code;
  return null;
end;
$$;

create trigger venues_retime_events after update of time_zone on public.venues
  for each row when (old.time_zone is distinct from new.time_zone)
  execute function public.venues_retime_events();

revoke execute on function public.venues_retime_events() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. There is always at least one group admin, so nobody can lock the team
--    screen by removing the last one (including themselves).
-- ---------------------------------------------------------------------------

create or replace function public.staff_roles_keep_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.role = 'group_admin'
     and (tg_op = 'DELETE' or new.role <> 'group_admin') then
    -- Serialise concurrent removals so two admins cannot remove each other.
    perform 1 from public.staff_roles where role = 'group_admin' for update;
    if not exists (
      select 1 from public.staff_roles r
      where r.role = 'group_admin' and r.id <> old.id
    ) then
      raise exception 'Enish needs at least one group admin. Add another '
        'group admin before removing this one.';
    end if;
  end if;
  return coalesce(new, old);
end;
$$;

create trigger staff_roles_keep_admin before update or delete on public.staff_roles
  for each row execute function public.staff_roles_keep_admin();

revoke execute on function public.staff_roles_keep_admin() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. A menu item always belongs to its section's venue. Before, a venue
--    editor could attach an item (tagged with their own venue) to another
--    venue's section. Row-level security checks the row after this trigger,
--    so an editor can now only add items to their own venue's sections.
-- ---------------------------------------------------------------------------

create or replace function public.menu_items_follow_section()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.venue_code := (select s.venue_code from public.menu_sections s
                     where s.id = new.section_id);
  return new;
end;
$$;

create trigger menu_items_follow_section
  before insert or update of section_id, venue_code on public.menu_items
  for each row execute function public.menu_items_follow_section();

-- Moving a section to another venue moves its items with it.
create or replace function public.menu_sections_move_items()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.menu_items set venue_code = new.venue_code where section_id = new.id;
  return null;
end;
$$;

create trigger menu_sections_move_items after update of venue_code on public.menu_sections
  for each row when (old.venue_code is distinct from new.venue_code)
  execute function public.menu_sections_move_items();

revoke execute on function public.menu_items_follow_section() from public, anon, authenticated;
revoke execute on function public.menu_sections_move_items() from public, anon, authenticated;

-- Align any existing items with their sections.
update public.menu_items i
set venue_code = s.venue_code
from public.menu_sections s
where s.id = i.section_id
  and i.venue_code is distinct from s.venue_code;
