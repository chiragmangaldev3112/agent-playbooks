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
curl -fsSL <install-script-url> -o install.sh && chmod +x install.sh
AGENT_PLAYBOOKS_SUPABASE_URL=<given-to-you> \
AGENT_PLAYBOOKS_SUPABASE_ANON_KEY=<given-to-you> \
  ./install.sh /path/to/your/project   # or no path, for the current directory
```

This copies `AGENTS.md` and `agent-playbooks/` into your project — fast, no
further setup, works the same regardless of which AI tool you use there.
The two environment variables point the installer at the access-checked
backend the actual playbook content is served from (see **How this is
distributed** below) — ask the maintainer for them.

Then open your AI coding tool in that project and ask it to follow
`agent-playbooks/project-bootstrap.md` once — the smart, context-aware pass
that grounds `AGENTS.md` in your project's real stack and wires the safety
guardrail + personas into whichever tool you're using there.

From then on, every actual task routes through
`agent-playbooks/core/engineering-loop.md` — it classifies the request
(bug, feature, review, test...) and sends it to the matching playbook.

## What's in the box

Grouped by kind of concern. This describes what each does — the actual
instruction text is delivered on install, not shown here (see below).

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
| `change-types/refactoring.md` | Behavior-preserving restructuring |
| `change-types/dependency-upgrades.md` | Bumping a dependency version safely |
| `change-types/database-migration.md` | Safe schema changes via expand/migrate/contract |
| `change-types/incident-response.md` | Restore service first, root-cause after |
| `autonomy/mission-mode.md` | Standing-objective autonomous operation, with an explicit autonomy dial |
| `autonomy/roles.md` | Reusable personas (Bug Hunter, Feature Builder, Code Reviewer, Test Writer, Manual/Exploratory Tester, Project Bootstrapper) |
| `safety/safety-guardrail.md` | A real, enforced block on destructive shell commands |
| `safety/memory-hygiene.md` | Don't trust a remembered fact once its source code has changed |
| `project-bootstrap.md` | Onboard an agent to an unfamiliar repo, and wire the guardrail + personas into it |
| `demo-video.md` | Generate a narrated screen-recording demo from a script, free tools only |

## How this is distributed

This repo ships the installer and this description — not the playbook
text itself. `install.sh` fetches the current release from a backend (its
schema is in `supabase/schema.sql`, fully readable) that logs a random
local install ID and can decline to serve a specific one. Full detail on
what that check does, what it doesn't do, and its known limits — read
`install.sh`'s own header comment and `supabase/schema.sql`'s comments
before relying on it for anything sensitive; nothing about the mechanism
is hidden from you, it's just not bundled inline here.

No email or personal information is collected by the installer. Disable
the check entirely with `AGENT_PLAYBOOKS_NO_CHECK=1` if your access isn't
gated (ask the maintainer).

## License

Two different licenses, deliberately:
- **This installer and repo**: MIT — see [LICENSE](LICENSE). Fork it,
  read it, run your own backend against the same schema, whatever.
- **The playbook content itself**, fetched on install: a separate,
  restrictive license, delivered as `agent-playbooks/LICENSE` inside every
  install — in short, use it in your own projects freely, but don't
  redistribute, republish, or resell it without the copyright holder's
  permission. Read that file (it's short) rather than assuming terms.
