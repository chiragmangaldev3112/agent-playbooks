-- Schema for the gated distribution backend. Run once in your Supabase
-- project's SQL editor.
--
-- Design: the public installer never carries the actual playbook content.
-- It calls the single RPC function below, which (a) logs the check-in,
-- (b) refuses if blocked, and (c) if allowed, returns the current release
-- archive (base64-encoded) directly in the response. No direct table
-- access is granted to anon/authenticated -- this function is the only
-- sanctioned path, and it is the only place content ever leaves the
-- database.

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

-- Each row is one publishable release: the full agent-playbooks/ +
-- AGENTS.md tree, packaged as a tar.gz and base64-encoded. Publish a new
-- version by inserting a row here and updating app_config.latest_version
-- to match -- see maintainer/package-release.sh for how the archive is
-- built (that script and this table's contents never go in the public repo).
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

  -- Never look up, let alone return, the archive for a blocked id.
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

-- To block an installation:
--   update installations set blocked = true,
--     blocked_message = 'Access revoked -- contact the maintainer.'
--   where id = '<installation id>';
--
-- To see usage:
--   select id, first_seen, last_seen, checkin_count, version, blocked
--   from installations order by last_seen desc;
--
-- To publish a release, after building the archive with
-- maintainer/package-release.sh (that script prints the exact SQL):
--   insert into releases (version, archive_base64) values ('1.0.1', '<base64>');
--   update app_config set latest_version = '1.0.1' where id = 1;
