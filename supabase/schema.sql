-- Schema for the gated distribution backend. Run once in your Supabase
-- project's SQL editor.
--
-- Design: zero friction for the installer -- it sends only a random local
-- ID it generated itself, nothing else, no signup step. That ID is logged
-- automatically on first use (self-registering, no manual step on your
-- side per person). The one lever you keep is after-the-fact: mark a
-- specific installation blocked and it stops being served on its next
-- check-in. Direct table access is closed entirely; check_in() is the
-- only sanctioned path, and content only ever leaves the database
-- through it.

-- Needed to compute sha256() for the watermark-lookup query near the
-- bottom of this file -- harmless to enable even if you never use it.
create extension if not exists pgcrypto;

create table if not exists installations (
  id uuid primary key,
  first_seen timestamptz not null default now(),
  last_seen timestamptz not null default now(),
  checkin_count integer not null default 1,
  version text,
  blocked boolean not null default false,
  blocked_message text
);

alter table installations enable row level security;

create table if not exists app_config (
  id int primary key default 1,
  latest_version text,
  notice text,
  constraint single_row check (id = 1)
);

insert into app_config (id, latest_version, notice)
values (1, '1.0.0', '')
on conflict (id) do nothing;

alter table app_config enable row level security;

-- archive_base64 stores a JSON object mapping each release file's
-- relative path to its base64 content (produced by
-- maintainer/package-release.sh) -- not a single tar.gz. This is
-- deliberate: it lets the check-in Edge Function inject a per-install
-- watermark into AGENTS.md's content at request time before returning
-- it, without needing to unpack/repack a compressed archive.
create table if not exists releases (
  version text primary key,
  archive_base64 text not null,
  created_at timestamptz not null default now()
);

alter table releases enable row level security;

create or replace function check_in(p_id uuid, p_version text default null)
returns table(blocked boolean, blocked_message text, latest_version text, notice text, archive_base64 text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_blocked boolean;
  v_blocked_message text;
  v_latest text;
  v_notice text;
  v_archive text;
begin
  insert into installations (id, version)
  values (p_id, p_version)
  on conflict (id) do update
    set last_seen = now(),
        checkin_count = installations.checkin_count + 1,
        version = coalesce(p_version, installations.version);

  select i.blocked, i.blocked_message into v_blocked, v_blocked_message
  from installations i where i.id = p_id;

  select c.latest_version, c.notice into v_latest, v_notice
  from app_config c where c.id = 1;

  if not v_blocked then
    select r.archive_base64 into v_archive
    from releases r where r.version = v_latest;
  end if;

  return query select v_blocked, v_blocked_message, v_latest, v_notice, v_archive;
end;
$$;

grant execute on function check_in(uuid, text) to anon;
revoke all on installations from anon, authenticated;
revoke all on app_config from anon, authenticated;
revoke all on releases from anon, authenticated;

-- Block a specific installation (the only real lever in this model --
-- there's no pre-entry gate, so this is an after-the-fact revoke, not a
-- prevention -- see the public README for what that does and doesn't mean):
--   update installations set blocked = true,
--     blocked_message = 'Access revoked -- contact the maintainer.'
--   where id = '<installation id>';
--
-- See usage:
--   select id, first_seen, last_seen, checkin_count, version, blocked
--   from installations order by last_seen desc;
--
-- Publish a release (after building the archive with
-- maintainer/package-release.sh, which prints this exact SQL):
--   insert into releases (version, archive_base64) values ('1.0.1', '<base64>');
--   update app_config set latest_version = '1.0.1' where id = 1;
--
-- Trace a leaked copy back to the install it came from: the Edge
-- Function watermarks AGENTS.md with a token computed as
-- sha256(install_id) truncated to the first 12 hex characters -- nothing
-- extra is stored, so given a token found in a leaked copy, find the
-- matching installation by recomputing the same hash for every row
-- (requires the pgcrypto extension, enabled once via
-- `create extension if not exists pgcrypto;`):
--   select id, first_seen, last_seen, version
--   from installations
--   where left(encode(digest(id::text, 'sha256'), 'hex'), 12) = '<token from the leaked copy>';
