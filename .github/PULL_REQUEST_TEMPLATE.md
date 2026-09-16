## What does this change?

<!-- What it does and why. Link an issue if there is one. -->

## Checklist

See [CONTRIBUTING.md](../CONTRIBUTING.md) for the full detail on any of these.

- [ ] Ran `shellcheck` on every changed `.sh` file
- [ ] Ran `./tests/install-smoke-test.sh` if this touches `install.sh`, the backend response shape, or `tests/`
- [ ] Ran `deno check supabase/functions/check-in/index.ts` if this touches the Edge Function
- [ ] Bumped `VERSION` and added an `INSTALLER_CHANGELOG.md` entry if this touches `install.sh` (the pre-commit hook blocks this locally, but CI doesn't re-check it — do it before pushing)
- [ ] This isn't a playbook *content* change — those aren't sourced in this repo (see CONTRIBUTING.md)
