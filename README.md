# Agent Playbooks

A portable rulebook for AI coding agents — how to fix bugs, build features,
review code, test frontend/backend work, run security reviews, and (if you
want it) operate autonomously against a standing mission. Works with Claude
Code, Antigravity, Cursor, GitHub Copilot/Codex, or any agent that can read
a text file.

## Why

Two separate problems, both real:

1. **Every tool wants its own file.** Different AI coding tools each
   expect instructions in their own format and location. This project has
   one generic instruction set instead, so you write the rules once and
   point every tool at the same source of truth.
2. **An agent left to its own judgment fails in the same few ways, every
   time.** It guesses at an ambiguous spec instead of asking. It grades its
   own work instead of checking it independently. It forgets a project's
   own conventions the moment a new session starts. It occasionally runs
   something destructive because nothing stopped it.

This is that process, written down once, usable everywhere — and every
playbook in it has been run against a real, throwaway test case at least
once, not just written and published.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/chiragmangaldev3112/agent-playbooks/main/install.sh -o install.sh
chmod +x install.sh
./install.sh /path/to/your/project   # or no path, for the current directory
```

Needs a shell that can run bash — macOS and Linux have this natively.
**On Windows**, run it via WSL or Git Bash, not a plain Command
Prompt/PowerShell session.

By default you get the current latest release. To install a specific past
version instead — see **[CHANGELOG.md](CHANGELOG.md)** for the full list
and what changed in each:

```bash
./install.sh --version 1.3.0 /path/to/your/project
# or: AGENT_PLAYBOOKS_VERSION=1.3.0 ./install.sh /path/to/your/project
```

This copies `AGENTS.md` and `agent-playbooks/` into your project — fast, no
setup, no account, no token — and prints the version it installed. It also
drops in a one-line `CLAUDE.md` (only if you don't already have one) that
just imports `AGENTS.md`, because Claude Code only auto-loads `CLAUDE.md`,
never `AGENTS.md`.

If you run it at a real terminal, it also asks which AI tool you're
using and generates real native artifacts for it — not just a copy of
the same text everywhere:

| Tool | What gets generated | Why |
|---|---|---|
| Claude Code | `.claude/skills/*/SKILL.md` (one per playbook, invocable via `/name`) + `.claude/agents/*.md` (the 6 personas) | Discoverable/invocable, not just background text |
| Cursor | `.cursor/rules/*.mdc` (Agent Requested mode) | Explicit `@name` mention, on top of the `AGENTS.md` it already reads natively |
| Antigravity | `.agents/skills/*/SKILL.md` | Its own docs never confirm it reads `AGENTS.md` automatically, unlike Cursor/Codex CLI — so this is the reliable path, not an assumption |
| Codex CLI | nothing extra | Reads `AGENTS.md` at the root natively — confirmed, this is the tool the convention originated from |
| GitHub Copilot | one `.github/copilot-instructions.md` pointer | Copilot has no semantic per-file matching, so one blanket file beats 30 always-on ones |
| Anything else / skip | nothing extra | Falls back to `AGENTS.md` alone — paste it into your tool's context manually if it doesn't read project files |

Every generated file is a **thin pointer** back to the real playbook in
`agent-playbooks/` — never a content copy — so nothing drifts out of sync
between the two if playbooks get updated later. Skip the prompt (or pipe
input, or set `AGENT_PLAYBOOKS_TOOL=none`) and you just get `AGENTS.md` +
`CLAUDE.md`, same as before.

**Installing for a specific tool without the interactive prompt** (e.g. in
CI, or if you already know which one you want):

```bash
AGENT_PLAYBOOKS_TOOL=claude      ./install.sh /path/to/your/project   # Claude Code
AGENT_PLAYBOOKS_TOOL=cursor      ./install.sh /path/to/your/project   # Cursor
AGENT_PLAYBOOKS_TOOL=antigravity ./install.sh /path/to/your/project   # Antigravity
AGENT_PLAYBOOKS_TOOL=codex       ./install.sh /path/to/your/project   # Codex CLI (nothing extra generated)
AGENT_PLAYBOOKS_TOOL=copilot     ./install.sh /path/to/your/project   # GitHub Copilot
AGENT_PLAYBOOKS_TOOL=none        ./install.sh /path/to/your/project   # AGENTS.md + CLAUDE.md only
```

**Claude Code only — choosing which model each generated sub-agent uses:**
by default, the six personas in `.claude/agents/*.md` (see
`autonomy/roles.md`) are split by what they actually do — a role that
*checks* someone else's work (Code Reviewer, Manual/Exploratory Tester)
gets the strongest model, a role that *does* the work a check will
independently catch mistakes in (Bug Hunter, Feature Builder, Test
Writer, Project Bootstrapper) gets a lighter/faster one. Override any of
that — one persona, one whole tier, or "just use one model for
everything":

```bash
# Everything on the strongest model
AGENT_PLAYBOOKS_TOOL=claude AGENT_PLAYBOOKS_MODEL_VERIFY=opus AGENT_PLAYBOOKS_MODEL_IMPLEMENT=opus \
  ./install.sh /path/to/your/project

# Everything on the lightest/fastest model
AGENT_PLAYBOOKS_TOOL=claude AGENT_PLAYBOOKS_MODEL_VERIFY=haiku AGENT_PLAYBOOKS_MODEL_IMPLEMENT=haiku \
  ./install.sh /path/to/your/project

# Just the default tiering, but pin one persona differently
AGENT_PLAYBOOKS_TOOL=claude AGENT_PLAYBOOKS_MODEL_CODE_REVIEWER=haiku \
  ./install.sh /path/to/your/project

# Leave it alone entirely -- the sane opus(verify)/sonnet(implement) default
AGENT_PLAYBOOKS_TOOL=claude ./install.sh /path/to/your/project
```

Cursor, Antigravity, Codex CLI, and Copilot have no equivalent
per-sub-agent model setting to wire this into today, so these variables
are silently no-ops for them — not a broken promise, there's just nothing
on their side to point it at yet.

Then open your AI coding tool in that project and ask it to follow
`agent-playbooks/project/project-bootstrap.md` once — the smart, context-aware pass
that grounds `AGENTS.md` in your project's real stack and wires the safety
guardrail + personas into whichever tool you're using there.

From then on, every actual task routes through
`agent-playbooks/core/engineering-loop.md` — it classifies the request
(bug, feature, review, test...) and sends it to the matching playbook.

## Day to day: how you'll actually use this

There's no command to learn and no skill name to memorize. You describe
what you want the way you already do, and the router
(`core/engineering-loop.md`) sends it to the matching playbook on its
own:

| You say | What actually happens |
|---|---|
| "Fix this bug where..." | Reproduces the failure first, fixes, re-confirms — never a fix based on a guess |
| "Add a feature that..." | Writes a failing test from the spec before any implementation code |
| "Review this PR" | Reviews the real diff, checks security separately, tells you what's confirmed vs. only assumed |
| "This endpoint is slow" | Profiles before touching anything, instead of guessing at "the slow part" |
| "Ship this to production" | Decides a staged rollout and rollback plan first, checks in before widening exposure |
| "This feature stores user data" | Classifies what's sensitive before deciding how to handle it, keeps it out of logs |
| "Document this codebase / database" | Maps real module or table boundaries from actual code/schema, not folder or column names |
| "Integrate with X's API" | Tests the real API behavior for real, never handles your credential directly |
| "Here's a recording of the bug" (any video/audio file) | Extracts audio + frames, transcribes locally, re-verifies every finding against that evidence, then routes each one through the engineering loop if you want it fixed |
| "Here's the spec/report" (PDF, Word doc, any format) | Extracts the text (and page images if it's scanned), reads a 600-page document the same way as a 6-page one via bounded chunks, re-verifies every finding, then routes each action item through the engineering loop if you want it acted on |
| Anything destructive (force-push, dropping a table) | Hard-blocked, not just discouraged |

That's the whole interface. You don't need to read all 33 files before
getting value from any one of them — the router finds the right one, and
each file is self-contained if you ever want to read the one that just
fired.

## What's in the box

Grouped by kind of concern. This describes what each does — the actual
instruction text is delivered on install, not shown here (see below). For
a visual map of every playbook's actual process, see
**[FLOWS.md](FLOWS.md)** — a flowchart per playbook, matching its real
numbered steps. For a concrete "here's what you'd say, here's what
happens" example for every single one, see **[EXAMPLES.md](EXAMPLES.md)**.
For what changed in each released version (and to install an older one on
purpose), see **[CHANGELOG.md](CHANGELOG.md)**.

| Playbook | What it's for |
|---|---|
| `core/engineering-loop.md` | Router + independent-verification rule — start every task here |
| `core/bug-fix.md` | Reproduce-before-fix workflow |
| `core/feature-development.md` | Test-first feature workflow |
| `core/clarify-before-building.md` | Resolve a genuinely ambiguous request before implementation starts |
| `core/issue-triage.md` | Sort a new bug/enhancement report into a category and status |
| `quality/code-review.md` | Diff review checklist |
| `quality/security-review.md` | Language-agnostic security checklist |
| `quality/architecture-review.md` | Design-level review: visibility, failure containment, access boundaries, operational control |
| `quality/frontend-testing.md` / `quality/backend-testing.md` | Test layering for UI and server code, usable by testers or developers |
| `quality/docs-sync.md` | Verify doc claims against real code, run the project's real linter |
| `quality/observability.md` | Instrument a feature so its failures surface before a user reports them |
| `quality/writing-style.md` | Commit messages, PR descriptions, and reports that read like someone who understands the change |
| `change-types/refactoring.md` | Behavior-preserving restructuring |
| `change-types/dependency-upgrades.md` | Bumping a dependency version safely |
| `change-types/database-migration.md` | Safe schema changes via expand/migrate/contract |
| `change-types/incident-response.md` | Restore service first, root-cause after |
| `change-types/release.md` | Decide blast-radius limits and rollback path before a release starts |
| `change-types/performance.md` | Profile before optimizing, measure the same way after |
| `autonomy/mission-mode.md` | Standing-objective autonomous operation, with an explicit autonomy dial |
| `autonomy/roles.md` | Reusable personas (Bug Hunter, Feature Builder, Code Reviewer, Test Writer, Manual/Exploratory Tester, Project Bootstrapper) |
| `autonomy/standing-permission.md` | A written, bounded grant letting the agent skip per-action confirmation for explicitly named actions only |
| `safety/safety-guardrail.md` | A real, enforced block on destructive shell commands |
| `safety/secret-scan.md` | A real, enforced block on committing real secrets/credentials |
| `safety/memory-hygiene.md` | Don't trust a remembered fact once its source code has changed |
| `safety/sensitive-data.md` | Classify data before deciding how strictly to handle it |
| `project/project-bootstrap.md` | Onboard an agent to an unfamiliar repo, and wire the guardrail + personas into it |
| `mapping/codebase-mapping.md` | Document a codebase module by module from real dependency structure, then optionally generate a skill/agent per module |
| `mapping/database-mapping.md` | Document a database table by table from the real schema and code usage, then optionally generate a skill/agent per table |
| `mapping/third-party-api-integration.md` | Analyze and test a third-party API for real (env-var credentials only, never handled or logged), then optionally map it onto your own schema |
| `project/project-audit.md` | Audit a whole project against the existing quality checklists, then fix only what's explicitly approved, with every fix independently reverified |
| `media/demo-video.md` | Generate a narrated screen-recording demo from a script, free tools only |
| `media/video-review.md` | Turn an existing recording (bug repro, feedback video, any format ffmpeg reads) into a verified report — summary, key points, bugs/gaps, fix-vs-build asks — then optionally route each ask through `core/engineering-loop.md` |
| `media/doc-review.md` | Turn a document (PDF/DOCX/ODT/RTF/etc.) into a verified report — summary, key points, queries it raises, fix-vs-build action items — reads even a several-hundred-page document in bounded chunks, then optionally routes each item through `core/engineering-loop.md` |

## Creating your own bot (a custom persona), with a demo

The six built-in personas in `autonomy/roles.md` (Bug Hunter, Feature
Builder, Code Reviewer, Test Writer, Manual/Exploratory Tester, Project
Bootstrapper) cover the common cases. A new one is four things written
down:

1. **Name** — the job, not a person ("Dependency Auditor," not "Dave").
2. **One-line remit** — what it does, when it's used.
3. **What it follows** — an existing playbook if one fits, or its own
   numbered process if nothing covers it yet.
4. **Access level** — read/run only, or read/write, with a one-line
   reason.

Worked example, already in the box:

> ## Dependency Auditor
>
> Checks dependencies for newly-disclosed vulnerabilities and whether a
> fixed, compatible version exists. Recurring cadence, not just on ask.
>
> Follow `change-types/dependency-upgrades.md` for the upgrade itself.
> First: cross-check the lockfile against a vulnerability database, and
> for anything flagged, confirm the advisory is reachable in how this
> codebase actually uses the package — not just present in the tree.
>
> Read/run only for the audit; upgrading is a separate step needing write
> access, per the linked playbook.

Before trusting a new persona, prove it: give it a real, answerable task
and check whether the answer is actually right, not just plausible —
`autonomy/roles.md`'s own rule for when delegating to one is worth it at
all.

Once it's proven, `media/demo-video.md` turns it into a shareable, narrated
screen-recording — write the scenes as plain `SAY:`/`SHOW:` lines,
generate the voice-over and screen capture with the included scripts
(free/local tools, no cloud TTS account needed), and you have a demo of
your new bot actually doing its job, not just a description of it.

## How this is distributed

This repo ships the installer and this description — not the playbook
text itself. `install.sh` calls a check-in endpoint with a random local
install ID (generated once on first install, never a name, email, or
machine identifier — no account or token needed). The endpoint logs the
check-in and — if that ID isn't blocked — returns the current release.
The endpoint itself
holds no credential a client could extract: it forwards to the real
backend using a key that lives only in the endpoint's own server-side
environment (`supabase/functions/check-in/index.ts`, schema in
`supabase/schema.sql` — both fully readable, nothing about the mechanism
is hidden from you).

No email or personal information is collected by the installer itself.

**One more thing this endpoint does, disclosed here rather than hidden**:
it appends a short, inconspicuous watermark comment to `AGENTS.md` before
returning it — a token derived from your install's own random ID (the
same one already generated locally, no new data collected). It's
invisible in normal markdown rendering and doesn't change how an AI
reads the instructions; it exists so that if a full copy of this content
ever turns up somewhere it shouldn't (redistributed, resold), it can be
traced back to which install it came from. It does not, and isn't meant
to, stop you from reading your own installed copy — nothing can do that
while an AI tool also needs to read these files as plain text to use
them; see `supabase/functions/check-in/index.ts` for the exact,
readable logic.

## Two different version numbers

`CHANGELOG.md` tracks the *content* version (`agent-playbooks/`) — the one
`--version`/`AGENT_PLAYBOOKS_VERSION` lets you pin to. `VERSION` and
`INSTALLER_CHANGELOG.md` in this repo track a separate thing: `install.sh`'s
own version. You'll basically never need the second one — `curl
.../install.sh` always fetches current `main` regardless, there's no "pin
to an old installer" use case the way there's a real one for old content —
it's tracked mainly so this repo's own release history reflects real,
distinct states of the installer.

## License

Two different licenses, deliberately:
- **This installer and repo**: MIT — see [LICENSE](LICENSE). Fork it,
  read it, run your own backend against the same schema, whatever.
- **The playbook content itself**, fetched on install: a separate,
  restrictive license, delivered as `agent-playbooks/LICENSE` inside every
  install — in short, use it in your own projects freely, but don't
  redistribute, republish, or resell it without the copyright holder's
  permission. Read that file (it's short) rather than assuming terms.
