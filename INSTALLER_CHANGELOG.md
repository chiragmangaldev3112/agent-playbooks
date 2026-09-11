# Installer changelog

This tracks **`install.sh`'s own version** — a separate axis from
`CHANGELOG.md`, which tracks the *content* (`agent-playbooks/`) it fetches.
You almost never need to think about this one: `curl .../install.sh` always
fetches current `main`, and there's no real case for pinning to an old
installer script the way `--version` lets you pin to old content — the tool
just gets bug fixes forward. This file exists mainly so the repo's Releases
reflect real, distinct states of the installer rather than being empty.

## 1.3.0 — 2026-09-11
New `--only <name>[,<name>...]` / `AGENT_PLAYBOOKS_ONLY` flag: install one
playbook (or a few) instead of the full 34-file set, plus whatever it
actually needs — a playbook's own direct references to another playbook
(one hop only, not followed further: `core/engineering-loop.md` links to
nearly every other playbook by design as the router, so a full transitive
follow explodes to almost the whole repo the moment anything references
it — confirmed by hitting exactly that explosion before bounding it), and
any script reference followed fully (a genuine functional need, not a "see
also" pointer — `--only safety-guardrail` correctly pulls in
`scripts/block-dangerous.sh`). `AGENTS.md`/`VERSION`/`LICENSE` always
included. The existing tool-artifact generators (Claude Skills, Cursor
rules) needed no changes — they already scan whatever's actually on disk,
so a reduced install produces a correctly-reduced set of generated
artifacts for free.

Three real bugs found building this, all by actually running it rather
than reading the code:
- macOS ships bash 3.2 by default (associative arrays need bash 4+) —
  `declare -A` crashed immediately on a real Mac. Rewritten with a plain
  array and a linear-search `contains()` helper.
- bash before 4.4 treats `"${arr[@]}"` on a truly empty array as an
  unbound variable under `set -u`, not an empty expansion — hit twice
  (once inside `contains()`, once building the phase-2 queue via
  `"${a[@]}" "${b[@]}"` concatenation) before guarding both.
- The actual blocker: `mktemp -d`'s path (under `/var/folders/...`) and
  the same directory resolved via `cd .. && pwd -P` (`/private/var/
  folders/...`, since `/var` is itself a symlink) never string-matched,
  so every "is this still inside the tree" check silently failed and
  nothing was ever pulled in as a dependency. Fixed by canonicalizing the
  playbooks root once via `pwd -P` before any comparison, found by adding
  real trace output and watching the exact path mismatch, not by
  inspection.

**Verified for real:** `--only bug-fix` (pulls in `writing-style.md` +
`engineering-loop.md`, stops there), `--only safety-guardrail` (pulls in
its script plus a cascaded dependency's scripts), multiple comma-separated
names, a nonexistent name (errors, doesn't silently succeed), the
full-path disambiguation form, Claude Code Skill generation against the
reduced set (exactly 3 Skills for a 3-file install, not 34), and the
default full install (still exactly 34 files, unaffected) — all run
against the live endpoint, not simulated.

## 1.2.2 — 2026-09-11
`install.sh`'s own header comment and `README.md`'s model-tiering section
still described Bug Hunter as "implement" tier — stale prose left behind
when 1.2.1 fixed the actual generation code to tag it "verify." The code
was already correct (confirmed again: `bug-hunter.md` resolves to `opus`
with no overrides), only the documentation around it wasn't. Fixed both.

## 1.2.1 — 2026-09-11
Bug Hunter's generated Claude Code sub-agent now defaults to `opus`
instead of `sonnet`, matching content v1.14.1's model-tier correction:
`core/engineering-loop.md` names "Bug Hunter re-running the repro" as
the independent-verification pass for a bug fix, so it needed the
*verify* tier's default, not *implement*'s — a fresh audit caught this
persona had been tagged the wrong tier when 1.2.0 first wired the
tagging through. Re-tested the generation logic standalone after the
change: `bug-hunter.md` now resolves to `opus` with no overrides set.

## 1.2.0 — 2026-09-11
Claude Code's generated sub-agents (`.claude/agents/*.md`) now get a real
`model:` field per persona instead of an unset/default one, matching
content v1.14.0's new verify/implement tagging in `autonomy/roles.md`:
Code Reviewer and Manual/Exploratory Tester (roles that catch someone
else's mistakes) default to `opus`; Bug Hunter, Feature Builder, Test
Writer, and Project Bootstrapper (roles whose output gets independently
re-checked anyway) default to `sonnet`. Overridable three ways, checked
most-specific first: `AGENT_PLAYBOOKS_MODEL_<PERSONA>` for one persona,
`AGENT_PLAYBOOKS_MODEL_VERIFY`/`AGENT_PLAYBOOKS_MODEL_IMPLEMENT` for a
whole tier (set both the same for "one model for everything"), or leave
both unset for the default split. README.md now documents concrete
install commands for each supported tool plus this override, non-
interactively.

**Verified for real:** the generation logic was extracted into a
standalone harness and run with no overrides (confirmed opus/sonnet
split), both tier vars set to the same value (confirmed uniform), and one
persona-specific override (confirmed it wins over the tier default) —
not assumed correct from reading the script. `bash -n install.sh` also
confirms no syntax errors from the edit.

## 1.1.1 — 2026-09-11
Fixed the script's own final "Next step" message (plus two maintainer-
facing comments near the top) still pointing at
`agent-playbooks/project-bootstrap.md` — the flat, pre-v1.12.0 content
path. The content itself moved to `agent-playbooks/project/project-
bootstrap.md` back in content v1.12.0, and `README.md`/`FLOWS.md`/
`EXAMPLES.md` were corrected for it already, but `install.sh` wasn't
part of that grep (it's a script, not a `.md` cross-reference) and got
missed. Caught by actually running the real installer end to end against
the live v1.13.1 content release, not by re-reading the script — every
real install since v1.12.0's content release until now printed a next
step pointing at a path that no longer exists.

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
