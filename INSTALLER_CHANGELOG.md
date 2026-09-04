# Installer changelog

This tracks **`install.sh`'s own version** — a separate axis from
`CHANGELOG.md`, which tracks the *content* (`agent-playbooks/`) it fetches.
You almost never need to think about this one: `curl .../install.sh` always
fetches current `main`, and there's no real case for pinning to an old
installer script the way `--version` lets you pin to old content — the tool
just gets bug fixes forward. This file exists mainly so the repo's Releases
reflect real, distinct states of the installer rather than being empty.

## 1.1.0 — 2026-09-04
Fixed a real bug in all three per-tool artifact generators (Claude Code
Skills, Cursor rules, Antigravity Skills): `CHANGELOG.md` was being picked
up as if it were a playbook, producing a nonsensical extra Skill/rule
telling the agent to "follow CHANGELOG.md exactly." Found while recording
a demo of a fresh install — the printed count (33) didn't match the real
playbook count (32), so it was checked rather than assumed correct.
`CHANGELOG.md` is now excluded the same way `README.md` and `EXAMPLES.md`
already were; verified against all three generators after the fix, each
now produces exactly 32.

## 1.0.0 — 2026-09-04
Start of version tracking for the installer itself. Everything before this
point is real commit history (see `git log`), but wasn't tracked against a
distinct installer version number at the time — assigning version numbers
to it retroactively would be a guess, not a record, so this starts a clean
count from here rather than inventing one. As of this point, `install.sh`
supports: per-tool native artifact generation (Claude Code Skills/agents,
Cursor rules, Antigravity Skills, Copilot pointer), a `CLAUDE.md` auto-link,
and `--version`/`AGENT_PLAYBOOKS_VERSION` to install a specific past content
release instead of always latest.
