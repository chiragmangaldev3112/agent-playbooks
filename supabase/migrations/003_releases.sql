-- Split from ../schema.sql -- see ../migrations/README.md for run order.
--
-- releases: one row per published version. archive_base64 is a JSON
-- object mapping each release file's relative path to its base64
-- content (produced by maintainer/package-release.sh), not a single
-- tar.gz. (This used to also let the check-in Edge Function inject a
-- per-install watermark into AGENTS.md at request time; removed once
-- the content was relicensed MIT -- see agent-playbooks/CHANGELOG.md
-- 1.18.0 -- since a token for tracing an unauthorized "leaked" copy
-- stopped making sense the moment redistribution became explicitly
-- licensed. The per-file shape is kept regardless: it's still what lets
-- manifest_json below map cleanly one hash per file.)
--
-- manifest_json / manifest_signature: a signed, sorted-key JSON map of
-- {relative path: sha256} for the same files, signed with the
-- maintainer's release-signing key (maintainer/release-signing-key,
-- never in this database or any repo). install.sh verifies the
-- signature against a fixed public key baked into the script, then
-- re-hashes every fetched file against this manifest, before writing
-- anything to disk -- so a compromised or spoofed version of this
-- backend can no longer silently swap in different content; it doesn't
-- hold the private key needed to produce a manifest install.sh will
-- accept. Both nullable only so this migration doesn't break on top of
-- pre-existing rows -- install.sh itself treats a release missing either
-- as unverifiable and refuses to install it, so in practice every
-- release actually served needs both.

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
