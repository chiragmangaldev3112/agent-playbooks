-- Split from ../schema.sql -- see ../migrations/README.md for run order.
--
-- app_config: single-row table (id always 1) holding the currently
-- published version and an optional notice string served to every
-- check-in.

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
