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
--
-- manifest_json / manifest_signature: a signed, sorted-key JSON map of
-- {relative path: sha256} for the same files (pre-watermark, for
-- AGENTS.md), signed with the maintainer's release-signing key
-- (maintainer/release-signing-key, never in this database or any repo).
-- install.sh verifies the signature against a fixed public key baked
-- into the script, then re-hashes every fetched file against this
-- manifest, before writing anything to disk -- so a compromised or
-- spoofed version of this backend can no longer silently swap in
-- different content; it doesn't hold the private key needed to produce
-- a manifest install.sh will accept. Both nullable only so this
-- migration doesn't break on top of pre-existing rows -- install.sh
-- itself treats a release missing either as unverifiable and refuses to
-- install it, so in practice every release actually served needs both.
create table if not exists releases (
  version text primary key,
  archive_base64 text not null,
  manifest_json text,
  manifest_signature text,
  created_at timestamptz not null default now()
);

alter table releases add column if not exists manifest_json text;
alter table releases add column if not exists manifest_signature text;

alter table releases enable row level security;

-- Adding p_requested_version below changes this function's signature
-- (uuid, text) -> (uuid, text, text). `create or replace function`
-- matches by signature, not name -- without the explicit drop, Postgres
-- would keep the old 2-arg function AND add this as a second overload,
-- which PostgREST can resolve ambiguously for a 2-key JSON body (ambiguous
-- between "call the 2-arg one" and "call the 3-arg one, default the
-- third"). Drop the old signature first so there's exactly one function.
--
-- Adding manifest_json/manifest_signature to the RETURNS TABLE shape below
-- is a second, separate reason to drop-first: `create or replace function`
-- refuses to change an existing function's return type even when the
-- argument signature is unchanged (Postgres error 42P13), so the (uuid,
-- text, text) overload from the change above must also be dropped before
-- this version can be created.
drop function if exists check_in(uuid, text);
drop function if exists check_in(uuid, text, text);

-- p_requested_version: optional. Omitted (the default, and the only mode
-- before this parameter existed) serves app_config.latest_version, same
-- as always. Set it to pin an install to a specific past release instead
-- -- install.sh's --version flag / AGENT_PLAYBOOKS_VERSION passes this
-- through. A version that doesn't exist in `releases` reuses the same
-- blocked/blocked_message shape the client already handles (print the
-- message, exit) rather than adding a new response field for one more
-- kind of "no archive returned" -- from the installer's point of view
-- both are just "didn't get content, here's why."
create or replace function check_in(p_id uuid, p_version text default null, p_requested_version text default null)
returns table(blocked boolean, blocked_message text, latest_version text, notice text, archive_base64 text, manifest_json text, manifest_signature text)
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
  v_manifest_json text;
  v_manifest_signature text;
  v_target text;
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
    v_target := coalesce(p_requested_version, v_latest);
    select r.archive_base64, r.manifest_json, r.manifest_signature
    into v_archive, v_manifest_json, v_manifest_signature
    from releases r where r.version = v_target;

    if v_archive is null and p_requested_version is not null then
      v_blocked := true;
      v_blocked_message := 'Version ' || p_requested_version || ' not found. See CHANGELOG.md for available versions.';
    end if;
  end if;

  return query select v_blocked, v_blocked_message, v_latest, v_notice, v_archive, v_manifest_json, v_manifest_signature;
end;
$$;

grant execute on function check_in(uuid, text, text) to anon;
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
-- Publish a release (after building the archive + signed manifest with
-- maintainer/package-release.sh, which prints this exact SQL):
--   insert into releases (version, archive_base64, manifest_json, manifest_signature)
--     values ('1.0.1', '<base64>', '<manifest json>', '<signature>');
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
