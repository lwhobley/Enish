-- Files uploaded to the `media` bucket (for example by dragging clips into the
-- Supabase dashboard) appear in the app without any extra step.
--
-- Folder convention inside the bucket:
--   intro/<file>                  plays on the app's opening screen
--   <category>/<venue-code>/<file> tied to one venue, e.g. happening/camden/night.mp4
--   <category>/<file>             group-wide, e.g. food/jollof.jpg
-- <category> is one of the media categories (venue, food, drink, event,
-- happening, experience, brand, intro). Videos (.mp4, .mov, .m4v) become
-- kind 'video'; everything else is a photo. Deleting the file removes it from
-- the app.

-- Public URL prefix for this project's bucket. Change per environment.
create or replace function public.media_public_base()
returns text language sql immutable
set search_path = ''
as $$ select 'https://gogjjqeykskyrotssnsr.supabase.co/storage/v1/object/public/media/' $$;

create or replace function public.media_register_upload()
returns trigger language plpgsql security definer
set search_path = ''
as $$
declare
  parts     text[] := string_to_array(new.name, '/');
  file_name text   := parts[array_length(parts, 1)];
  cat       text   := parts[1];
  venue     text;
  ext       text   := lower(substring(file_name from '\.([^.]+)$'));
begin
  if new.bucket_id <> 'media'
     or file_name like '.%'                 -- dashboard folder placeholders
     or array_length(parts, 1) < 2
     or cat not in ('venue', 'food', 'drink', 'event', 'happening',
                    'experience', 'brand', 'intro') then
    return new;
  end if;

  if array_length(parts, 1) >= 3 then
    select v.code into venue from public.venues v where v.code = parts[2];
  end if;

  insert into public.media (kind, category, venue_code, title, storage_path,
                            public_url, source)
  values (
    case when ext in ('mp4', 'mov', 'm4v') then 'video' else 'photo' end,
    cat,
    venue,
    initcap(replace(replace(regexp_replace(file_name, '\.[^.]+$', ''), '-', ' '), '_', ' ')),
    new.name,
    public.media_public_base() || new.name,
    'upload'
  )
  on conflict (storage_path) do nothing;
  return new;
end $$;

create or replace function public.media_unregister_upload()
returns trigger language plpgsql security definer
set search_path = ''
as $$
begin
  if old.bucket_id = 'media' then
    delete from public.media where storage_path = old.name and source = 'upload';
  end if;
  return old;
end $$;

revoke execute on function public.media_register_upload() from public, anon, authenticated;
revoke execute on function public.media_unregister_upload() from public, anon, authenticated;

create trigger media_register_upload after insert on storage.objects
  for each row execute function public.media_register_upload();
create trigger media_unregister_upload after delete on storage.objects
  for each row execute function public.media_unregister_upload();
