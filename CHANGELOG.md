# Changelog

Every entry here corresponds to a real, tested change to the playbook
content — not a version bump for its own sake. See `agent-playbooks/VERSION`
for the currently-installed version; a fresh `install.sh` run always fetches
the latest, and now prints the version it installed.

## 1.4.2 — 2026-09-04
`install.sh` can now install a specific past release instead of always
latest: `--version 1.3.0` or `AGENT_PLAYBOOKS_VERSION=1.3.0`. The check-in
backend gained an optional `p_requested_version` parameter (omitted =
unchanged latest-serving behavior). Also republished every version from
1.0.0 onward in the current archive format — versions before 1.1.6 had
been stored in an old tar.gz format from before the JSON-file-map format
existed, which this version's install.sh couldn't have read; found this
by actually testing a specific-version install against production, not by
inspection. Production was also caught up to this release itself (nothing
past 1.2.0 had actually been published before now).

## 1.4.1 — 2026-09-04
`install.sh` now prints the actual version it installed ("Installed
agent-playbooks vX.Y.Z"), reading it from the fetched archive's own
`agent-playbooks/VERSION` rather than leaving it invisible. Added this file,
and a git pre-commit hook (`maintainer/check-version-bump.sh`) that blocks
committing a playbook-content change unless `VERSION` and this file are
both bumped in the same commit — enforced, not just a habit to remember.

## 1.4.0 — 2026-09-04
Added `quality/writing-style.md` (commit messages, PR descriptions, and
reports should read like someone who understands the change — cut padding,
back claims with what was checked, bullet only genuine lists) and a bounded
escalate-when-stuck rule in `bug-fix.md`/`engineering-loop.md`: after
repeated attempts that don't narrow the cause, stop and report what's ruled
out instead of continuing to guess.

## 1.3.0 — 2026-09-04
Added `safety/secret-scan.md` — a real, enforced block on committing secrets
(AWS/GitHub/Slack/Stripe/Google tokens, private keys), primarily via a
tool-agnostic git pre-commit hook, with an optional Claude Code hook layer.

## 1.2.2 — 2026-09-04
Added spec-traceability (every case in an external test plan needs an
accounted-for test, automated or explicitly marked not-automatable) and
test-healing discipline (diagnose against the contract before changing a
failing test, never weaken an assertion to force it green) to
`backend-testing.md`/`frontend-testing.md`.

## 1.2.1 — 2026-09-03
`demo-video.md`: burned-in captions timed against real narration audio, and
a Piper neural-TTS option for a non-robotic voice on any platform.

## 1.2.0 — 2026-09-03
Added `EXAMPLES.md` — one real, worked example per playbook.

## 1.1.9 — 2026-09-03
`architecture-review.md`: scale review depth to blast radius, and check for
a recorded past decision before flagging a fresh gap.

## 1.1.8 — 2026-09-02
Removed the Graft reference; closed the same token-efficient-context problem
with three playbook-native improvements to `codebase-mapping.md`/
`engineering-loop.md` instead.

## 1.1.7 — 2026-09-01
Published, but no changelog entry was recorded at the time and the
original content isn't reliably distinguishable from 1.1.6/1.1.8 now —
noted here for an honest record rather than guessing at what changed.

## 1.1.6 — 2026-09-01
Added per-install watermarking — a deterministic, traceable token woven into
`AGENTS.md`'s content on each install.

## 1.1.5 — 2026-09-01
`third-party-api-integration.md`: batch-test all read-only endpoints without
per-endpoint asks, single combined confirmation for side-effecting ones, and
an optional OpenAPI/Postman export.

## 1.1.4 — 2026-09-01
`third-party-api-integration.md`: handle a catalog/index as its own scope
decision, and sort endpoints read-only vs. side-effecting before calling any.

## 1.1.3 — 2026-09-01
Fixed two real gaps found through live use: inspect an auth gate directly
instead of asking the human to guess it, and never leave an optional step
silent — say what was skipped and why.

## 1.1.2 — 2026-09-01
Corrected Antigravity's and Copilot's AGENTS.md-support claims after direct
verification against each tool's current docs.

## 1.1.1 — 2026-09-01
Routed the four whole-project playbooks (`codebase-mapping.md`,
`database-mapping.md`, `third-party-api-integration.md`, `project-audit.md`)
through `engineering-loop.md`.

## 1.1.0 — 2026-09-01
Added `project-audit.md`, and a Mermaid flow diagram for every playbook.

## 1.0.9 — 2026-09-01
Added `codebase-mapping.md`, `database-mapping.md`, and
`third-party-api-integration.md`.

## 1.0.8 — 2026-09-01
Wired a standing-permission grant offer into `project-bootstrap.md`.

## 1.0.7 — 2026-09-01
Added first-time execution guidance across playbooks, and
`autonomy/standing-permission.md`.

## 1.0.6 — 2026-08-31
Added `release.md`, `performance.md`, `observability.md`, and
`sensitive-data.md`.

## 1.0.5 — 2026-08-31
`demo-video.md`'s voice pipeline made cross-platform, with honest
voice-quality notes per platform.

## 1.0.4 — 2026-08-31
Added response-shape (not just status-code) assertions to
`backend-testing.md`, and a cross-reference to `security-review.md`.

## 1.0.3 — 2026-08-31
`backend-testing.md`: derive the test matrix from the real request/DB
schema, not memory or assumption.

## 1.0.2 — 2026-08-31
`frontend-testing.md`: documented a real browser-driven check plus
video/screenshot evidence capture.

## 1.0.1 — 2026-08-31
Added an explicit planning step to `engineering-loop.md`.

## 1.0.0 — 2026-08-31
First tracked release.
