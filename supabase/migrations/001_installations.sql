-- Split from ../schema.sql for sequential upload to Supabase -- see
-- ../migrations/README.md for the full split and run order.
--
-- installations: one row per installer-generated random local ID,
-- self-registering on first check-in. blocked/blocked_message is the
-- only after-the-fact revoke lever -- see check_in() in 004.

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
