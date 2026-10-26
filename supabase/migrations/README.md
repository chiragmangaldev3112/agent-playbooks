# Supabase migrations

Split from `../schema.sql` for sequential upload to a Supabase project's
SQL editor (some editors/clients choke on one large multi-statement
paste, or you want to review each piece before running it). Run in
order — each file after the first depends on the tables the ones before
it created:

1. `001_installations.sql`
2. `002_app_config.sql`
3. `003_releases.sql`
4. `004_check_in_function.sql`

`../schema.sql` remains the single canonical copy of this schema for
anyone who just wants to paste it in one go — these files are the same
SQL, split, not a second version to keep in sync by hand. If you change
the schema, change `../schema.sql` first and re-split.

## Operating this backend (unchanged from `../schema.sql`)

Block a specific installation (the only real lever in this model —
there's no pre-entry gate, so this is an after-the-fact revoke, not a
prevention — see the public README for what that does and doesn't mean):

```sql
update installations set blocked = true,
  blocked_message = 'Access revoked -- contact the maintainer.'
where id = '<installation id>';
```

See usage:

```sql
select id, first_seen, last_seen, checkin_count, version, blocked
from installations order by last_seen desc;
```

Publish a release (after building the archive + signed manifest with
`maintainer/package-release.sh`, which prints this exact SQL):

```sql
insert into releases (version, archive_base64, manifest_json, manifest_signature)
  values ('1.0.1', '<base64>', '<manifest json>', '<signature>');
update app_config set latest_version = '1.0.1' where id = 1;
```
