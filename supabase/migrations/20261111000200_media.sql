-- Photos, illustrations and video for the app, stored in the app's own storage.

-- Per-venue accent colour, so every venue has its own vibrant identity.
alter table public.venues add column accent_color text
  check (accent_color is null or accent_color ~ '^#[0-9A-Fa-f]{6}$');

update public.venues set accent_color = c.color
from (values
  ('soho', '#C9A227'), ('shoreditch', '#2E9E6B'), ('camden', '#D7385E'),
  ('camberwell-buka', '#F06A2B'), ('camberwell-24', '#4C5FD5'), ('brixton', '#F2A93B'),
  ('croydon', '#1FA2A6'), ('finchley-rd', '#8E44AD'), ('oxford-street', '#C8553D'),
  ('ilford', '#0F8B5F'), ('knightsbridge', '#2F6FDE'), ('lewisham', '#FF7A59'),
  ('old-kent-road', '#B83280'), ('manchester', '#E0A800'), ('glasgow', '#1E8C93'),
  ('dubai', '#D4A017'), ('dubai-yacht', '#2B7BB9'), ('houston', '#E2522F'),
  ('accra', '#2E9E6B'), ('nairobi', '#D7385E'), ('dubai-palm', '#2B7BB9'),
  ('covent-garden', '#8E44AD')
) as c(code, color)
where venues.code = c.code;

create table public.media (
  id            uuid primary key default gen_random_uuid(),
  kind          text not null default 'photo' check (kind in ('photo', 'illustration', 'video')),
  category      text not null check (category in
                  ('venue', 'food', 'drink', 'event', 'happening', 'experience', 'brand', 'intro')),
  venue_code    text references public.venues (code) on delete set null,
  title         text,
  storage_path  text not null unique,
  public_url    text not null,
  source        text not null default 'upload' check (source in ('website', 'instagram', 'upload')),
  source_ref    text,
  sort_order    integer not null default 0,
  status        text not null default 'published' check (status in ('draft', 'published')),
  created_at    timestamptz not null default now()
);

create index media_category_idx on public.media (category, venue_code);

create trigger media_audit after insert or update or delete on public.media
  for each row execute function public.audit_row();

alter table public.media enable row level security;

create policy media_read_published on public.media
  for select to anon, authenticated using (status = 'published');
create policy media_staff_read on public.media
  for select to authenticated using (public.can_edit_venue(venue_code));
create policy media_write on public.media
  for all to authenticated using (public.can_edit_venue(venue_code))
  with check (public.can_edit_venue(venue_code));

grant select on public.media to anon;
grant select, insert, update, delete on public.media to authenticated;

-- Public-read bucket: files are served by public URL. Only group admins upload.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('media', 'media', true, 104857600,
        array['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/quicktime'])
on conflict (id) do nothing;

create policy media_bucket_admin_insert on storage.objects
  for insert to authenticated with check (bucket_id = 'media' and public.is_group_admin());
create policy media_bucket_admin_update on storage.objects
  for update to authenticated using (bucket_id = 'media' and public.is_group_admin());
create policy media_bucket_admin_delete on storage.objects
  for delete to authenticated using (bucket_id = 'media' and public.is_group_admin());
