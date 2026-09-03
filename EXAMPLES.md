# Usage examples

One realistic, worked example per playbook — a scenario, what you'd
actually say, and what happens. Not a full transcript, enough to see the
discipline play out in practice. You never need to name a playbook
directly; describe the situation the way you normally would and
`core/engineering-loop.md` routes it for you — the "you say" lines below
are just realistic phrasing, not required syntax.

## Core

### `core/engineering-loop.md`
**Scenario:** any task at all — this is the front door.
**You say:** "Fix this bug where the checkout button does nothing on mobile."
**What happens:** classified as a bug fix, routed to `bug-fix.md`. Once
implemented, a fresh evidence-based pass verifies it independently before
anything is reported done.

### `core/bug-fix.md`
**Scenario:** a report that a signup form silently fails for some users.
**You say:** "Users say signup sometimes fails with no error message."
**What happens:** first reproduces the failure with a real test/script
before touching any code — turns out empty `phone` values crash a
downstream validator. Fixes the root cause, re-runs the exact repro to
confirm it now passes, and only then reports it fixed.

### `core/feature-development.md`
**Scenario:** adding CSV export to an admin dashboard.
**You say:** "Add a button to export the users table as CSV."
**What happens:** writes a failing test from the spec first (including
an empty-table edge case), confirms it fails for the right reason, then
implements the minimum to pass — no speculative "export as JSON too"
option nobody asked for.

### `core/clarify-before-building.md`
**Scenario:** a request that could mean two different things.
**You say:** "Add pagination to the orders list."
**What happens:** asks one concrete question — "should page size be
fixed or user-configurable?" — because that changes the actual
implementation, rather than guessing and building the wrong one. Doesn't
ask about styling details that don't change what gets built.

### `core/issue-triage.md`
**Scenario:** a pile of unsorted bug reports in a tracker.
**You say:** "Triage these five new reports."
**What happens:** each gets a category (Defect/Enhancement) and a status
— one report with no repro steps becomes Incomplete with a specific ask
for what's missing, not silently left untouched.

## Quality

### `quality/code-review.md`
**Scenario:** a teammate's PR adding a new payment endpoint.
**You say:** "Review this PR."
**What happens:** pulls the real diff (not the PR description), checks
it against a security pass, confirms the tests actually ran rather than
trusting "tests pass" as a claim, and reports findings split into
Blocking / Suggestions / Confirmed good.

### `quality/security-review.md`
**Scenario:** a diff adding a search-by-username API.
**You say:** "Security review this change."
**What happens:** walks the checklist, finds the query string is
interpolated directly into SQL, and reports it with a concrete scenario
(`username=' OR '1'='1`) rather than just flagging "looks risky."

### `quality/architecture-review.md`
**Scenario:** a new shared event that three teams will consume.
**You say:** "Review this design before we ship it."
**What happens:** scales scrutiny to the fact that three teams depend on
it — checks who can publish to the topic, whether one stuck consumer
backs up the others, and whether the payload carries data one consumer
shouldn't see by default.

### `quality/frontend-testing.md`
**Scenario:** a new modal component.
**You say:** "Write tests for this modal."
**What happens:** tests by role/label the way a user would find things
(not internal class names), checks keyboard/focus behavior on open and
close, and confirms a new test actually fails before the fix and passes
after.

### `quality/backend-testing.md`
**Scenario:** a new `/orders` POST endpoint.
**You say:** "Write tests for the new orders endpoint."
**What happens:** reads the real request schema first — every
`required: true` field becomes a missing-field test case straight off
the spec, not from memory — plus a concurrency case and an
idempotency check for retried requests.

### `quality/docs-sync.md`
**Scenario:** a README that hasn't been touched in a year.
**You say:** "Check if the README is still accurate."
**What happens:** verifies each documented command actually runs,
finds one flag that was removed two versions ago, updates that one
line, and leaves the rest of the accurate prose untouched rather than
rewriting it for style.

### `quality/observability.md`
**Scenario:** a new background job syncing data every 5 minutes.
**You say:** "Build this sync job."
**What happens:** names the signal that would catch it silently failing
for hours (seconds-since-last-success, emitted every run, not just on
success), logs at the actual failure points, and sets the alert
threshold well before "quietly broken all day" territory.

## Change types

### `change-types/refactoring.md`
**Scenario:** an untested 200-line function that needs breaking up.
**You say:** "Refactor this function into smaller pieces, same behavior."
**What happens:** writes characterization tests capturing today's actual
output first (since none exist), then extracts functions in small steps,
running the suite after each one — not one big rewrite checked only at
the end.

### `change-types/dependency-upgrades.md`
**Scenario:** bumping a major version of an HTTP client library.
**You say:** "Upgrade axios to the latest major version."
**What happens:** reads the changelog for breaking changes first, greps
the codebase for the specific API it flags as changed, upgrades that one
dependency alone (not bundled with unrelated bumps), and runs the full
suite before calling it done.

### `change-types/database-migration.md`
**Scenario:** renaming a column used across several services.
**You say:** "Rename the `user_id` column to `customer_id`."
**What happens:** refuses to do it as one step — expands (adds the new
column), migrates (dual-writes and backfills), and only contracts (drops
the old one) once every caller is confirmed on the new shape, each stage
its own deploy.

### `change-types/incident-response.md`
**Scenario:** the API is returning 500s for all users right now.
**You say:** "Production is down, API is 500ing for everyone."
**What happens:** assesses blast radius, defaults to rolling back the
last deploy rather than debugging live in production, confirms the
rollback against the real error-rate signal, and only root-causes
properly once service is actually restored.

### `change-types/release.md`
**Scenario:** shipping a fix to how discount codes are validated at checkout.
**You say:** "Ship this checkout fix."
**What happens:** classifies it as higher-risk despite looking simple,
puts it behind a flag at 5% of traffic first, names the real health
signal (checkout completion rate, not "no complaints yet"), and confirms
before widening — not a straight deploy to everyone.

### `change-types/performance.md`
**Scenario:** a reported slow search endpoint.
**You say:** "The search endpoint feels slow with lots of results."
**What happens:** profiles before touching anything rather than guessing
at "the slow part" — finds an unused debug-string computation running on
every row, removes just that, and measures before/after with real
numbers instead of "feels faster."

## Autonomy

### `autonomy/mission-mode.md`
**Scenario:** wanting an agent to keep the test suite green continuously.
**You say:** "Take ownership of keeping CI green on this repo."
**What happens:** runs on a written mission file with an explicit
autonomy level (starting `bounded`, not the riskiest option by default),
loops perceive→plan→act→verify→report, and stops immediately at any
listed hard stop rather than improvising past it.

### `autonomy/roles.md`
**Scenario:** wanting a recurring dependency-vulnerability check.
**You say:** "I want something that regularly checks for vulnerable
dependencies."
**What happens:** rather than one of the six built-in personas, a new
one gets defined in four lines (name, remit, which playbook it follows,
access level) — a "Dependency Auditor" that's read-only for the audit
itself, matching the existing template rather than inventing a new format.

### `autonomy/standing-permission.md`
**Scenario:** tired of re-approving test runs and feature-branch commits.
**You say:** "I'm fine with you running tests and committing to feature
branches without asking each time."
**What happens:** a written, scoped grant covers exactly those two
action types — a later request to merge to `main` or deploy still gates
normally, since it was never named in the grant, no matter how related
it seems.

## Safety

### `safety/safety-guardrail.md`
**Scenario:** wiring up a hard block against destructive commands.
**You say:** "Set up the safety guardrail for this project."
**What happens:** wires the deny-pattern check into the tool's
pre-execution hook, then actually tests it — one known-safe command runs
normally, one known-dangerous one (like `git push --force`) gets hard
blocked, not just logged.

### `safety/memory-hygiene.md`
**Scenario:** an agent recalls "this function handles retries" from an
earlier session.
**You say:** (no special phrasing needed — this applies automatically
whenever a stored memory is about to be acted on)
**What happens:** before trusting that recalled fact, it re-checks the
actual function — if it's been rewritten since, the memory is treated as
unverified and re-derived from the current code, not acted on as-is.

### `safety/sensitive-data.md`
**Scenario:** a "download my data" account-settings feature.
**You say:** "Build a feature letting users export all their account data."
**What happens:** classifies fields (name/email as directly identifying,
support-ticket text as high-sensitivity by default), rejects a plan to
log the full export payload for debugging, and defines a retention
window before shipping instead of "we'll figure out deletion later."

## Top level

### `project-bootstrap.md`
**Scenario:** pointing an agent at a repo it's never seen before.
**You say:** "Onboard yourself to this codebase."
**What happens:** detects the real test/lint commands from the actual
config (never invents one that "should" work), writes a grounded
`AGENTS.md`, wires the safety guardrail if the tool supports it, and
actually runs the detected commands to confirm they work before
reporting done.

### `codebase-mapping.md`
**Scenario:** inheriting a codebase with zero documentation.
**You say:** "Document this codebase module by module."
**What happens:** finds real module boundaries from the dependency
graph rather than folder names (catching, for example, two folders that
freely import each other's internals and are really one coupled unit),
writes a verified doc per module, and only generates a matching skill
per module if you ask for it afterward.

### `database-mapping.md`
**Scenario:** a schema with no reliable documentation.
**You say:** "Document the database."
**What happens:** documents each column from its real constraints and
how code actually uses it — catching, for instance, an `is_active`
column that the app only ever uses to mean "email confirmed," not
"account enabled" — and flags a foreign key that was dropped in a past
migration but is still relied on by a live query.

### `third-party-api-integration.md`
**Scenario:** integrating with a partner API whose docs are behind a login.
**You say:** "Analyze this partner API and help us integrate with it."
**What happens:** inspects the actual login form to find the real auth
mechanism rather than asking you to guess, tests read-only endpoints in
one batch, asks once (not per-endpoint) before touching anything that
creates or charges something real, and writes the verified findings to
a doc you can actually implement against.

### `project-audit.md`
**Scenario:** inheriting a project with an unknown amount of technical debt.
**You say:** "Audit this project and tell me what's wrong."
**What happens:** runs the existing quality checklists across the whole
project, reports findings ranked by real impact, and stops to wait for
explicit approval on what to fix — it doesn't start changing code just
because it found something.

### `demo-video.md`
**Scenario:** wanting a narrated walkthrough of a new feature.
**You say:** "Make a demo video showing off the new export feature."
**What happens:** turns a plain-text script (`SAY:`/`SHOW:` lines) into
narrated audio and a screen recording using free local tools, then
actually plays back the result to confirm timing lines up before calling
it done — not just assembling files and assuming it works.
