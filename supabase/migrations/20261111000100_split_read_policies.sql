-- Guest reads must never call the staff helper functions. anon has no EXECUTE on
-- is_group_admin() / can_edit_venue(), so a combined "published OR staff" policy fails
-- with 42501 for guests. Split each read policy by role instead.

-- Venues
drop policy if exists venues_read_published on public.venues;
drop policy if exists venues_admin_write on public.venues;
create policy venues_read_published on public.venues
  for select to anon, authenticated using (published);
create policy venues_admin_read on public.venues
  for select to authenticated using (public.is_group_admin());
create policy venues_admin_write on public.venues
  for all to authenticated using (public.is_group_admin()) with check (public.is_group_admin());

-- Menu sections
drop policy if exists menu_sections_read on public.menu_sections;
drop policy if exists menu_sections_write on public.menu_sections;
create policy menu_sections_read_published on public.menu_sections
  for select to anon, authenticated using (status = 'published');
create policy menu_sections_staff_read on public.menu_sections
  for select to authenticated using (public.can_edit_venue(venue_code));
create policy menu_sections_write on public.menu_sections
  for all to authenticated using (public.can_edit_venue(venue_code))
  with check (public.can_edit_venue(venue_code));

-- Menu items
drop policy if exists menu_items_read on public.menu_items;
drop policy if exists menu_items_write on public.menu_items;
create policy menu_items_read_published on public.menu_items
  for select to anon, authenticated using (status = 'published');
create policy menu_items_staff_read on public.menu_items
  for select to authenticated using (public.can_edit_venue(venue_code));
create policy menu_items_write on public.menu_items
  for all to authenticated using (public.can_edit_venue(venue_code))
  with check (public.can_edit_venue(venue_code));

-- Events (members-only events are excluded for guests until membership is built)
drop policy if exists events_read on public.events;
drop policy if exists events_write on public.events;
create policy events_read_published on public.events
  for select to anon, authenticated using (status = 'published' and not members_only);
create policy events_staff_read on public.events
  for select to authenticated using (public.can_edit_venue(venue_code));
create policy events_write on public.events
  for all to authenticated using (public.can_edit_venue(venue_code))
  with check (public.can_edit_venue(venue_code));

-- News
drop policy if exists news_posts_read on public.news_posts;
drop policy if exists news_posts_write on public.news_posts;
create policy news_posts_read_published on public.news_posts
  for select to anon, authenticated using (status = 'published');
create policy news_posts_staff_read on public.news_posts
  for select to authenticated using (public.can_edit_venue(venue_code));
create policy news_posts_write on public.news_posts
  for all to authenticated using (public.can_edit_venue(venue_code))
  with check (public.can_edit_venue(venue_code));
