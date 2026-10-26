-- Split from ../schema.sql -- see ../migrations/README.md for run order.
-- Depends on 001_installations.sql, 002_app_config.sql, and
-- 003_releases.sql already having run (this function reads/writes all
-- three tables).
--
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
