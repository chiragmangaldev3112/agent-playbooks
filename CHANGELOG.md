# Changelog

Every entry here corresponds to a real, tested change to the playbook
content — not a version bump for its own sake. Once installed, see
`agent-playbooks/VERSION` inside your own project for the version you
have (this file itself isn't fetched into that directory — it's the
same content this repo publishes it from, kept here for browsing before
you install); a fresh `install.sh` run always fetches the latest, and
now prints the version it installed.

## 1.26.0 — 2026-09-18
Prompted by outside feedback (a Reddit comment on the launch post)
observing that reliable playbooks need an explicit stopping rule, not
just procedural steps. Checked this against all 37 files rather than
taking the premise at face value: `core/engineering-loop.md` already has
a universal stalled-loop bound ("three attempts, then stop and report
what's ruled out") that names `core/feature-development.md` and
`change-types/refactoring.md` as examples by name — but neither of those
files, nor most others with a genuinely iterative shape, actually pointed
back to it. A direct invocation of a playbook by name (several tools
support `/name`/`@name` invocation per the README) can bypass the router
entirely, so a reader landing on one of these files directly had no way
to discover the bound existed.

Added a short pointer (not a duplicate of the rule — that would drift out
of sync over time) to the seven playbooks with a real, unbounded-retry
shape and no existing connection to the central rule:
`core/feature-development.md`, `change-types/refactoring.md`,
`change-types/dependency-upgrades.md`, `change-types/performance.md`,
`change-types/incident-response.md` (a stricter, escalate-to-a-human
version, given live production impact is a different stakes profile than
routine retrying), `quality/backend-testing.md`, and
`quality/frontend-testing.md`.

Deliberately did *not* add one to `quality/docs-sync.md` or
`quality/receiving-code-review.md`, despite both surfacing in the initial
grep-based sweep: both are bounded, finite-checklist processes (verify N
claims once each, respond to N review items once each), not unbounded
retry loops — forcing a stopping rule onto a process that doesn't loop
would be padding, not a fix. Also correctly left `autonomy/mission-mode.md`
untouched: it already has its own explicit, more detailed stopping/hard-stop
rule (`safety-guardrail.md`'s exit-2 hard stops plus its own "same fix
failing more than N times" trigger) — the initial automated sweep flagged
it as a gap due to a keyword-search false negative, corrected before
any change was made there.

## 1.25.0 — 2026-09-18
A full independent re-evaluation of all 37 playbooks — three fresh-eyes
passes (no prior context from the files that added `config-protection.md`
or the doc-review/markitdown work), each reading its assigned files in
full rather than skimming. Every finding below was independently
re-verified against the actual repo before being fixed, not applied on
the reviewing pass's say-so.

**Real bugs fixed:**
- **`scripts/claude-code-secret-hook.sh` had a real security-relevant
  gap**: its matcher only ever covered `Write`/`Edit`, so a `MultiEdit`
  call writing a secret bypassed this Claude Code hook (layer 2)
  entirely — layer 1 (the git pre-commit hook) would still have caught
  it at commit time, but the defense-in-depth layer had a real hole.
  Fixed: the matcher now includes `MultiEdit`, and the extraction logic
  was rewritten to check every `new_string` in `MultiEdit`'s `edits`
  array (its payload has no top-level `content`/`new_string` field the
  way `Write`/`Edit` do, so widening the matcher alone would have
  matched the call and silently extracted nothing). Re-tested for real:
  a fake-but-correctly-shaped secret placed in the *second* edit of a
  real `MultiEdit` payload is now caught, a clean `MultiEdit` still
  passes, across both the `jq` and `python3`-fallback code paths.
- **Two files wrongly attributed an "ask before hard-to-reverse action"
  instinct to `safety/safety-guardrail.md`** (`quality/frontend-testing.md`
  step 14, `quality/exploratory-qa.md` step 1) — that script's own text
  explicitly disclaims covering anything but a fixed shell-command
  blocklist ("merging, pushing to a shared branch, deploying... have no
  corresponding deny pattern here at all"). The actual source of that
  instinct is `AGENTS.md` rule 5, which safety-guardrail.md itself
  defers to. Both references corrected.
- **`quality/frontend-testing.md` mischaracterized `media/demo-video.md`**
  as being for "a narrated *marketing* walkthrough... not for test
  evidence" — demo-video.md's own scope explicitly includes "testers
  recording a bug reproduction as a narrated video." Reworded to state
  the real distinction (framework-native automated evidence vs. a
  narrated walkthrough for a human audience) without the false claim.
- **`quality/backend-testing.md`'s read-only/write-access step split
  silently omitted steps 9 and 10** from either list — step 10
  explicitly involves editing code/tests to fix a regression, so it
  belongs in the write-access group along with step 9 (running the
  suite that was just authored). Fixed to list steps 8–10 together.
- **`project/project-bootstrap.md` had two real defects from the
  `config-protection.md` step added in 1.24.0**: step 5 claimed to
  reuse "the same `Write|Edit`-matching hooks list step 3/4 already
  created," but step 3 (safety-guardrail) wires a `Bash`-matched hook,
  not `Write|Edit` — only step 4 does. Corrected to cite step 4 alone.
  Separately, the Flow diagram folded config-protection's git-hook layer
  (explicitly "unconditional too" in the prose) into the same node as
  the *conditional* per-tool hooks, contradicting the step 4 pattern the
  diagram already got right for secret-scan.md. Diagram corrected to
  show both git hooks as unconditional, matching the prose.
- **`autonomy/roles.md` cited the wrong part of `README.md`** for its
  Claude Code model-tagging mechanism — the per-tool wiring-artifact
  table it pointed to doesn't cover this at all; the actual content
  lives in a separate section further down. Reference corrected to name
  that section directly instead of a vague "wiring notes."
- **`media/video-review.md`'s frame-interval example was mathematically
  wrong**: it claimed a 12-second clip and a 4-hour recording both land
  around ~120 frames total, but the stated formula (`duration ÷ 120`,
  floored at 3s) gives a 12-second clip exactly 4 frames, not 120 — the
  3s floor dominates for anything under ~6 minutes. Corrected to
  describe both regimes accurately.
- **`safety/config-protection.md`'s git pre-commit hook had a real,
  if cosmetic, bug**: `--diff-filter=AMD` fetched added and deleted
  entries only for the loop to immediately discard everything that
  wasn't a modification. Narrowed to `--diff-filter=M`, and the fix
  itself prompted two new real tests (deleting an ordinary file,
  deleting the tracked config file) confirming neither is wrongly
  treated as a blockable edit.
- **`EXAMPLES.md` was missing entries for `media/doc-review.md` and
  `media/video-review.md` entirely**, despite the README's explicit
  promise of a worked example for every playbook. Both added.
- Two minor cross-reference style inconsistencies fixed (a same-directory
  reference written as `../category/file.md` instead of a bare filename,
  in `change-types/release.md` and `autonomy/standing-permission.md` —
  both already resolved correctly, just inconsistent with house style).

**Verification methodology**: structural checks (all 280+ cross-references
across all 37 files resolve to real paths; README.md/FLOWS.md/EXAMPLES.md
each independently confirmed to enumerate exactly all 37) were run
directly, not delegated. Content-level review (factual accuracy, internal
consistency, overstated "verified" claims) was delegated to three
independent passes specifically so the review wouldn't just re-check the
same assumptions the authoring pass already held — every finding those
passes surfaced was independently re-verified against the actual repo
state before any fix was made (re-reading the exact lines quoted, and for
the `roles.md` finding, checking README.md directly rather than trusting
"this isn't documented anywhere" at face value — it turned out to be
documented, just not in the specific table the finding pointed at, which
changed the fix from "add missing content" to "correct an imprecise
pointer").

## 1.24.1 — 2026-09-18
Fixed `safety/config-protection.md`'s own verification instructions
after a full re-check of the 1.24.0 release found a real, repeatable
trap in them: step 2 said to "discard or re-stage" the rejected commit's
staged change before continuing, without naming an exact command. That
vague instruction was tried and failed twice, independently — the
original verification, and a later separate re-verification pass of the
already-shipped playbook both used plain `git checkout -- <file>`, which
silently does nothing when the file is already staged (it restores from
the index, not `HEAD`), producing a confusing false-"blocked" result on
an unrelated file in both cases. The underlying mechanism
(`block-config-edit.sh`, the git pre-commit hook, the Claude Code
`PreToolUse` shim) was confirmed working correctly throughout both
incidents — this was purely a documentation gap in how to reset a
scratch repo between verification steps, now fixed by naming the exact
correct command (`git checkout HEAD -- <file>`) instead of a vaguer
instruction that repeatedly failed to prevent the same mistake.

## 1.24.0 — 2026-09-18
Added `safety/config-protection.md` — a new, 37th playbook, plus
`scripts/block-config-edit.sh` and `scripts/claude-code-config-protection-hook.sh`
— a real, enforced block on editing an existing linter/formatter/style
config file (ESLint, Prettier, Biome, Ruff, ShellCheck, Stylelint,
markdownlint), while still allowing first-time creation of one. Targets a
real failure mode: an agent facing a failing lint/format check weakening
the config instead of fixing the flagged code, the same "real exit code,
no LLM judgment" shape as `safety-guardrail.md`/`secret-scan.md`.

Two-layer wiring, same reasoning as `secret-scan.md`: a git pre-commit
hook (primary, tool-agnostic) plus a Claude Code `PreToolUse` hook
(defense in depth). The two-layer split isn't cosmetic — checked directly
against a real, current Cursor checkout (its actual `hooks.json` and hook
event list) and confirmed it has no `beforeFileEdit`/`beforeWrite` event
at all, only `afterFileEdit` (fires after the write already landed, so it
can revert but never prevent one). That's why the git layer, not a
per-tool pre-write hook, is the one every project gets regardless of
which AI coding tool is in use.

Both scripts were run for real, not just written: 8 direct cases against
`block-config-edit.sh` (protected-vs-not, exists-vs-first-time-creation,
a case-insensitive-filesystem match, a dangling symlink at a protected
path, stdin input, a nested path, and confirming `pyproject.toml` is
correctly never blocked), the Claude Code JSON shim against real-shaped
`Write`/`Edit`/`MultiEdit` payloads (both the `jq` and `python3`-fallback
paths), and the git pre-commit hook in a real scratch repo — a first-time
`.eslintrc.js` commit succeeding, a modification to that same tracked
file being genuinely rejected, and an ordinary source file continuing to
commit normally afterward. `project/project-bootstrap.md` now wires this
in alongside the existing two guardrails (renumbered as a new step 5).

Also folds in the source of this addition: `docs/social-preview.png` was
regenerated (it had been stuck at "35 Playbooks" since before the 36th
playbook shipped) and every "36 playbooks" reference describing the
current playbook count (not the still-36-playbook demo video, which
wasn't re-recorded) was updated to 37 across `README.md`,
`docs/index.html`, and `docs/llms.txt`.

## 1.23.0 — 2026-09-18
`media/doc-review.md`/`scripts/extract-doc-text.sh` now handle
`.xlsx`/`.xls` spreadsheets, via `markitdown`
(https://github.com/microsoft/markitdown) rather than `pandoc`
(https://github.com/jgm/pandoc). This was prompted by a question about
whether converting extracted documents to Markdown would reduce token
usage — tested for real rather than assumed, against a table-bearing
`.docx`, a synthetic `.pdf`, and a `.pptx` deck, using `tiktoken` for
real token counts. Result: Markdown lost or tied on every format already
handled (plain text extraction is already the more token-efficient
choice — Markdown's own syntax costs more than it saves), so nothing
changed for `.docx`/PDF/`.pptx`. The one real gap: `pandoc` 3.11 lists
`.xlsx` as a supported input format but was confirmed to fail on a real,
valid `.xlsx` file (`Failed to parse XLSX: Entry not found:
xl//xl/worksheets/sheet1.xml`), and has no `.xls` support at all.
`markitdown` reads both correctly, so it's used there and only there.
Two more real findings from the same testing, both now documented in
`doc-review.md`: `markitdown`'s own `.docx` table conversion has a
verified bug (blank header row, real headers demoted to a data row —
confirmed by inspecting the raw output), and its spreadsheet reader
silently turns literal cell values like `"None"`/`"NA"`/`"NULL"` into
blank cells (a `pandas` null-inference behavior, confirmed against the
source `.xlsx` directly) — both are why `markitdown` stays scoped to
spreadsheets rather than adopted more broadly, and why the playbook now
tells a reviewer to double-check any blank spreadsheet cell against the
source file. `extract-doc-text.sh`'s `.docx`/PDF paths were re-run
unchanged to confirm no regression, and the missing-`markitdown`-on-PATH
error path was verified for real.

## 1.22.0 — 2026-09-16
`scripts/record-screen.sh` now supports `--region=X,Y,W,H` on `start` and
`timed`, cropping the output to one fixed rectangle instead of the full
screen. Found the need for this the hard way while preparing a new demo
video: a full-screen test recording on a real machine captured a private
Microsoft Teams conversation that happened to be open, and a second
attempt (after adding a naive full-screen-capture-then-trust-the-window
approach) instead captured the recording tool's own host application
window rather than the intended terminal, due to focus/z-order not being
guaranteed across separate steps. `--region` fixes the actual risk (only
the cropped bytes ever reach disk, regardless of what else is on screen)
and was verified by driving real commands into a real, positioned
terminal window and confirming the output contains exactly that
window's content and nothing else. Also fixed a real bug hit while
building this: `mapfile` (bash 4.0+) doesn't exist on macOS's default
`/bin/bash` (3.2) -- confirmed by actually hitting "mapfile: command not
found" on a real Mac, replaced with a portable `while read` loop, the
same constraint `install.sh`'s own comments already document elsewhere
in this project.

## 1.21.0 — 2026-09-16
New playbook: `quality/exploratory-qa.md` (36th playbook). Closes a real
gap found by comparing this project against a commercial autonomous-QA
product's actual feature set, not just its marketing headline: every
existing testing playbook (`frontend-testing.md`, `backend-testing.md`,
even `project-audit.md`) assumes you already know what to test — a
named flow, a spec, a diff. Nothing covered the "here's a URL, no other
direction" starting point: map what the app actually offers first,
prioritize, then hand each discovered journey to the existing testing
disciplines rather than re-inventing them.

Wired into `core/engineering-loop.md`'s classifier and routing rules so
it's reachable the same way every other playbook is — a user never
needs to name it directly. Added to `README.md`'s catalog and
`EXAMPLES.md`.

Verified for real, not just written: ran the playbook's own process
(map → prioritize → test → report) against this project's own live
GitHub Pages site before publishing. It found a real bug (a page-level
horizontal-overflow defect at mobile width, caused by the engineering-
loop diagram's `min-width` escaping its own scroll container) that was
fixed and re-verified as part of the same pass — the playbook's process
actually surfaced something real on its first real run, not a
hypothetical.

Revised once more before publishing, after checking the same commercial
product's fuller feature breakdown (not just its homepage) against the
first draft: added an explicit standing console/network-error check
(page can render correctly while still throwing an error nobody would
notice without checking), theme/light-dark consistency mapping, a hand-
off to `safety/security-review.md` alongside the two testing playbooks (a
security check needs exactly the surface this playbook's discovery pass
already produces), WCAG contrast ratios and keyboard-trap testing beyond
`frontend-testing.md` step 8's per-control checklist, and a proactive
performance check (slow network calls, render-blocking resources, long
main-thread tasks) that no existing playbook covered outside a reactive,
already-reported slowdown. The one thing not adopted: the commercial
product's actual "time-travel" deterministic-replay debugging technology
-- that's a specific runtime capability, not a process a playbook's
wording can provide; noted as a real, narrower gap rather than papered
over.

## 1.20.0 — 2026-09-16
Docs-only clarification, no behavior change: this file's own opening note
said "see `agent-playbooks/VERSION` for the currently-installed version"
without explaining that `agent-playbooks/` doesn't exist as a path in the
*public* repo someone browsing this file on GitHub would be looking at
(content isn't sourced there -- it's fetched by `install.sh` at install
time). A repo browser who hadn't installed yet could go looking for a
directory that isn't there. Reworded to say so directly.

## 1.19.0 — 2026-09-16
Replaced the per-install watermark with a static attribution line.
Previously, the check-in backend appended a unique, per-install token to
`AGENTS.md` at request time, meant to trace a "leaked" (unauthorized)
copy back to the install it came from. That stopped making sense the
moment 1.18.0 relicensed this content MIT: there's no such thing as an
unauthorized copy to trace anymore, since redistribution is now
explicitly permitted. Removed the whole mechanism (the backend no
longer mutates any content before serving it) and replaced it with one
permanent line baked directly into `AGENTS.md`'s own source, present
identically in every install:
`<!-- agent-playbooks (MIT): https://github.com/chiragmangaldev3112/agent-playbooks -->`.
This is a strictly simpler and more trustworthy design than before, not
just a smaller one -- the backend is now a pure passthrough with zero
runtime content mutation of any kind, so what's signed is provably
exactly what's served, byte for byte.

## 1.18.0 — 2026-09-16
Relicensed this content from the previous restrictive, non-redistributable
license to MIT -- the same license the installer/repository has always
used. `agent-playbooks/LICENSE` (installed with every copy) now reads
MIT, matching `LICENSE` in the public repo. This means: fork it,
redistribute it, modify and republish it, build a competing product on
it -- all now explicitly permitted, not just "use it in your own
project" as before. A deliberate tradeoff, not an oversight: gives up
the ability to restrict redistribution/resale of this specific content
in exchange for removing the single biggest trust/adoption friction
point raised across multiple independent reviews of this project (an
"MIT" badge on the repo while the actual content underneath carried a
separate restrictive license read as a bait-and-switch to a visitor
deciding whether to install). Once released under this version, this
exact content can't be retroactively restricted again for anyone who
already has it -- see the public repo's INSTALLER_CHANGELOG.md 2.0.1/2.0.0
entries for the unrelated installer-side signing work from the same week,
which is unaffected by this change (a release's signature still proves
authorship and integrity regardless of license terms).

## 1.17.0 — 2026-09-15
Added a new `README.md` section, "How to invoke a skill, once it's
wired in" — the wiring section documents how a tool becomes aware of a
playbook, but not how a person actually triggers one once it's wired,
and that gap had never been covered. Splits every one of the 15 tools
into three groups: relevance-matched with no command needed (Claude
Code, Antigravity's Model Decision mode, Cursor's Agent Requested mode,
Gemini CLI's `activate_skill`, Factory Droid, Grok Build, Devin CLI, and
Pi's default mode), explicit invocation by name (`/name` in Claude Code
and Hermes Agent, `@name` in Cursor and Antigravity, `/skill:name` in
Pi, the native `Skill`/`skill` tool in Kimi Code/OpenCode, a whole
custom-agent profile via `copilot --agent <name>` in GitHub Copilot
CLI), and no skill-level invocation at all (OpenAI Codex CLI/App and VS
Code Copilot Chat route everything through `AGENTS.md`/
`.github/copilot-instructions.md` directly, with nothing to name).

Every specific claim reuses a fact already fetched and cited during the
1.16.0 pass (the same tool docs), not a new round of research — this
entry organizes and exposes that existing research under a new heading
rather than gathering anything new. No re-verification against live
docs was performed for this entry specifically; if a claim here turns
out stale, it was already stale in 1.16.0's wiring section it's drawn
from.

## 1.16.0 — 2026-09-15
Extended `README.md`'s "Wiring into specific tools" section from 5 tools
to 15, plus a new "Getting started" section pointing a new reader at
`AGENTS.md`, `core/engineering-loop.md`, and the wiring section in order:

- **New tool entries**: GitHub Copilot CLI (split out from the existing
  GitHub Copilot entry, which covered only VS Code Copilot Chat and the
  cloud coding agent — the standalone CLI's own docs describe automatic
  `AGENTS.md` discovery with no toggle documented anywhere, unlike VS
  Code Copilot Chat's explicit `chat.useAgentsMdFile` setting), Codex App
  (OpenAI's cloud/IDE Codex surfaces — same
  `AGENTS.md` handling as the CLI, but a detached-HEAD git model that
  needs an explicit "Create branch here" step before commit/push/PR),
  Gemini CLI, Devin CLI, Factory Droid, Grok Build (xAI), Kimi Code,
  OpenCode, Pi, and Hermes Agent (NousResearch).
- Each new entry states, for that specific tool: whether it reads
  `AGENTS.md` (or an equivalent) automatically and unconditionally, any
  accepted alternate filenames, and its own per-file Skill/rule directory
  convention if it has one (exact path and required frontmatter) — the
  same two facts the five pre-existing entries already cover, at the same
  level of detail.
- `AGENTS.md`'s own opening line and closing pointer, previously naming
  only Claude Code/Antigravity/Cursor/Copilot/Codex by name, now name the
  full expanded list.

**Verified for real:** every claim above was fetched from that tool's own
current official documentation in this pass — not recalled, not inferred
from a similarly-named or forked tool's behavior, and not taken from a
third-party blog post standing in for an official source. This followed
the same discipline the existing Antigravity/Copilot/Cursor/Codex CLI
notes already required (per this file's own prior entries, that pass had
already caught two claims that didn't hold up under direct verification —
the same failure mode this pass was watching for). Two corrections came
out of it before anything was written down: "Grok Build CLI" is not
xAI's own product name (it's "Grok Build", CLI command `grok` — used
here with a note rather than silently substituted without saying so),
and Devin CLI turned out to be a genuinely separate product from cloud
Devin with its own (not identical) instructions/rules mechanism, not
just cloud Devin running in a terminal. Hermes Agent's `AGENTS.md`-loading
behavior wasn't stated on the first official page fetched (only that the
file exists and belongs in project directories) — rather than write the
entry from that weaker source, a second, more specific official page was
fetched and confirmed the automatic load order directly (`.hermes.md` →
`AGENTS.md` → `CLAUDE.md` → `.cursorrules`, first match wins). Pi required
confirming which of several unrelated products named "Pi" was meant
before citing anything, to avoid attributing one product's documented
behavior to a different one sharing its name. None of the ten
tools were installed or run directly in this environment — every claim
reflects current official documentation, not a live test in the tool
itself, and this is a fast-moving space; re-check if something doesn't
line up. Every new cross-reference was checked to resolve to a real path
by hand, the same way as the 1.15.0 pass; this release touched no
per-playbook cross-references, only `README.md` and `AGENTS.md`'s own
tool-list prose.

**A second, independent re-verification pass (prompted by user request,
after the above had already shipped in this same working state) found one
real error and one real overclaim, both fixed before anything was
committed:**

- **Real error:** the Pi entry stated "Pi core ships no bundled
  skill-directory convention of its own" — that line was never actually
  checked; it was carried over from an unrelated tool-mapping reference
  (about subagents and task lists, not skills) that simply didn't mention
  a skills mechanism, and its silence was wrongly read as confirmation
  none exists. Fetching Pi's own README and its dedicated `docs/skills.md`
  directly turned up a real one: `SKILL.md` under any of
  `~/.pi/agent/skills/`, `~/.agents/skills/`, `.pi/skills/`, or
  `.agents/skills/` (checked in that order, first match wins on a name
  collision), following the cross-vendor Agent Skills standard
  (agentskills.io) with `name`/`description` required frontmatter. The
  entry below is rewritten from that source instead of the absence that
  produced the wrong claim.
- **Real overclaim:** the Devin CLI entry called `.agents/skills/<name>/
  SKILL.md` the "recommended path" — "recommended" was only what
  Cognition's docs said for *cloud* Devin's skills convention; the Devin
  CLI research explicitly listed several accepted paths without marking
  any of them preferred. Reworded to list the paths without the
  unsupported "recommended" claim.

Neither of these was caught by the resolver/balance/hook checks the first
pass ran — those check structure, not whether a claim matches its source.
This pass instead re-read every new paragraph against the original
research findings line by line, which is what actually caught both.

## 1.15.0 — 2026-09-15
Three additions closing gaps found by comparing this repo against a
different agent-instruction project's approach to the same code-change
loop, adapted into this repo's own conventions rather than copied:

- **`quality/receiving-code-review.md`** (new): the implementer's side of
  a code review, to sit alongside `code-review.md`'s reviewer side —
  verify feedback against the actual codebase before implementing it,
  resolve every unclear item before acting on any of them, and grep for
  real callers before building out a "do it properly" request rather
  than expanding code nothing uses. Wired into `core/engineering-loop.md`
  step 4 (findings from a review pass now route here before further
  changes), `README.md`, `AGENTS.md`, and `EXAMPLES.md`.
- **`core/engineering-loop.md` step 4**: a second new bullet — don't
  state a completion claim ("should pass now," "looks right," "this is
  done") ahead of the verification command actually being run in that
  same pass. The substance (evidence before claims) already existed in
  this step; this names the specific phrasing pattern that lets a claim
  outrun its evidence.
- **`autonomy/roles.md`**: a new section, "Splitting a multi-step
  delegation into right-sized pieces," extending the file's existing
  when-to-delegate test with how to size and isolate the pieces once you
  do — cut a multi-step task into pieces small enough for a fresh
  delegate to complete from its own brief alone, give each delegate only
  what its piece needs (never the delegator's own session history or a
  running summary of prior pieces), and review each piece before
  delegating the next.

**Verified for real (the receiving-code-review.md addition):** ran a
controlled paired test, not just read for plausibility. Built a small
throwaway three-file codebase (a pricing module with one intentionally-
correct-but-suspicious-looking function carrying a comment citing a past
incident, one genuinely dead legacy function, and one real stub-validation
gap) and a matching three-item review comment, then dispatched two fresh
subagents against identical copies — one with no playbook (just told to
respond to the review normally), one given this file's full text and told
to follow it. Both agents independently reached the same right call on
two of the three items (pushed back on the "fix" that the code's own
comment and cited incident number already contradicted; implemented the
genuinely-missing validation, scoped honestly to only the field actually
read downstream, flagging the scoping decision instead of guessing at a
fuller schema) — for those two items, ordinary model reasoning already
covers what this playbook asks for, so this run didn't show a difference
worth attributing to the playbook. The third item was the real,
measured effect: asked to "flesh out" a function whose own docstring
already said it had no current caller, the no-playbook agent invested
real effort doing exactly that anyway — a new currency-decimals lookup
table plus a new 8-case test file — while noting its own doubt about the
function being dead without acting on that doubt. The playbook-following
agent, under step 4's explicit grep-before-building-out instruction,
confirmed there were no callers and removed the function instead,
citing that step by name in its own report. One real, targeted behavior
change, not a blanket improvement across every item — recorded honestly
rather than oversold. The `engineering-loop.md` phrasing bullet and the
`roles.md` delegation-sizing section were not put through an equivalent
paired test — both are prose additions consistent with patterns already
established and shipped elsewhere in this repo (the phrasing bullet
extends this same step's existing evidence-before-claims rule; the
delegation section extends `roles.md`'s existing when-to-delegate test),
not independently pressure-tested via a subagent scenario the way the
new file above was. Every new cross-reference (from the new file, and
into it) was checked to resolve to a real path by hand; no automated
link resolver exists in this working copy to re-run.

## 1.14.5 — 2026-09-14
Closed real, confirmed bypasses in the two enforced security backstops,
found by actually running crafted inputs through each script rather than
by inspection:

- `scripts/detect-secrets.sh`: a secret token split across a literal
  `\r\n` (CRLF) line ending passed through clean, the same hole a `\n`-only
  strip had already been fixed for. Now strips `\r` too.
- `scripts/block-dangerous.sh`: five indirection bypasses that hid a
  dangerous command from the same-clause deny checks — `eval`/`bash -c`
  of a variable, a base64-decoded payload piped to a shell, `xargs rm -rf`
  with the target supplied through the pipe, and `rm -rf $(echo /)` with
  the target hidden inside a command substitution. Added a variable-eval
  deny pattern, a pipeline-group-level xargs/decode-execute check, and a
  command-substitution unwrap for the rm-target check. Verified against
  the full existing regression set (all previously-fixed cases and
  false-positive fixes) with no new false positives.

## 1.14.4 — 2026-09-14
Closed a gap between `safety/memory-hygiene.md` (stale-fact correctness)
and `safety/sensitive-data.md` (data classification): added a "Persisted
agent content" section covering the write-time side — before persisting
anything derived from a real client's system into memory, a changelog, or
a report, genericize the identifying details (client/project name, staging
URLs) at write time rather than as a cleanup pass after it's already
distributed. Found this gap after a real changelog entry had named a
specific client's system before being corrected.

## 1.14.3 — 2026-09-11
Documentation completeness pass on two features added earlier today
(model tiering in `autonomy/roles.md`, the humanizer reference in
`quality/writing-style.md`) — both had only been added to the actual
playbook file, never to the surrounding docs that describe it:

- `EXAMPLES.md`: added a worked example for the Claude Code model-tiering
  override under `autonomy/roles.md` (alongside the existing
  custom-persona example), and a mention of the humanizer follow-up under
  `quality/writing-style.md`'s existing example.
- `README.md`: `quality/writing-style.md`'s one-line description now
  mentions the humanizer reference, matching what's actually in the file.

## 1.14.2 — 2026-09-11
A third audit pass, run in parallel: one reviewer told specifically to
attack the two scripts harder than the previous round did, one re-checking
every file the previous round touched for regressions, one checking
`public-repo`'s consistency against this content ahead of a release. Two
of the three came back with real, reproduced findings; the third (the
public-repo one) is tracked in that repo's own installer changelog.

- **`scripts/block-dangerous.sh` — a false positive introduced by round
  1.14.1's own fix, plus 4 more real bypasses:**
  - Decoupling "has dangerous flags" from "has a dangerous target" (the
    1.14.1 fix for target-position bypasses) checked the whole command as
    one blob, so an unrelated second command joined by `&&`/`;` could
    supply the "target" half of the match on its own —
    `` rm -rf ./build && ls / `` and `` git push origin feature && ls -f ``
    (both entirely harmless) were being wrongly blocked. Fixed properly
    this time: the command is now split into clauses on chain/pipe
    operators *before* any pattern runs, and every check — including the
    fork-bomb pattern, pulled out of the per-clause loop since its own
    signature contains `|`/`&` as syntax, not real command separators —
    runs per clause, not against the joined string.
  - `rm -rf /root`, `` rm -rf $HOME ``, and `rm -rf ~/` (trailing slash)
    all passed through — the target list didn't cover the home directory's
    other common spellings. Added.
  - Re-verified: 26 block cases (all of 1.13.x/1.14.1's plus these new
    ones) now block, 19 legitimate/chained commands (including the two
    false positives above and the fork bomb) now pass correctly.
- **`scripts/detect-secrets.sh` — the exact newline-splitting bug
  `block-dangerous.sh` fixed in 1.14.1 had never been carried over here.**
  An AWS key, a GitHub token, or a JWT split across one literal `\n`
  (hard-wrapped file content, a pasted diff) passed through untouched.
  Fixed — but not the same way: flattening to a *space* (what
  `block-dangerous.sh` needed, since its tokens are naturally
  space-separated) doesn't reassemble a secret token, since none of these
  shapes allow internal whitespace either; newlines are now stripped
  entirely instead. Re-verified against both the newline-split repro
  (now blocked) and the existing real/false-positive suite (unchanged),
  plus a repo-wide self-scan (still 0 flagged).
- **`safety/safety-guardrail.md` and `safety/secret-scan.md`**: both told
  readers to "use a scratch repo" for verification without saying how —
  and for the force-push check specifically, a bare `git init` doesn't
  even demonstrate the danger being tested (nothing to force-push over).
  Added a concrete bare-repo-plus-clone recipe to safety-guardrail.md, and
  a simpler plain-`git init` recipe to secret-scan.md (which only needs a
  local commit, not a remote).
- **`public-repo/install.sh` and `public-repo/README.md`**: both still
  described Bug Hunter as "implement" tier in prose/comments after 1.14.1
  retagged it *verify* in the actual generation logic — the code was
  right, the documentation around it wasn't. Fixed in `public-repo`
  directly; see its own `INSTALLER_CHANGELOG.md`.

**Verified for real:** full regression suite re-run after every change —
26 block-dangerous.sh block cases + 19 pass-through cases (including the
two newly-fixed false positives) + 8 detect-secrets.sh cases, 53/53 — plus
a repo-wide self-scan of every `.md` file (0 flagged) and the
cross-reference resolver (0 broken links, 40 files).

## 1.14.1 — 2026-09-11
A second, harder audit pass on the current (post-1.14.0) state — this time
instructed specifically to re-run the two enforcement scripts with
invented bypass attempts rather than trust the 1.13.x fix descriptions,
and to check the newest additions (1.14.0's model tiering and
writing-style elevation) for problems the first pass wouldn't have had a
chance to introduce yet. It found real gaps; every one below was
independently re-reproduced before being fixed, and re-tested after.

- **`scripts/block-dangerous.sh` — three more real bypasses, confirmed
  live:**
  - A bundled short git flag (`git push -fu origin main`, `-uf`) wasn't
    recognized as a force-push. Confirmed with a real bare-repo push, not
    just the regex: git itself reported `(forced update)` and the other
    clone's commit was actually discarded. Fixed by matching any short
    flag *containing* `f` after `git push`, not only a standalone `-f`.
  - `rm -rf /*`, `rm -rf /.`, `rm -rf //`, and `rm -rf /a /` (dangerous
    target last, not first) all passed through — the old check required
    the target to immediately follow the flags as one exact token. Fixed
    by checking "has the dangerous flags" and "has a dangerous target
    anywhere in the command" as two independent conditions instead of one
    adjacency-requiring pattern, and widening the target list to cover
    the glob/dot/double-slash spellings above.
  - **Structural**: a literal newline embedded in the command text (e.g.
    `` printf 'git push origin main\n--force' ``) defeated the force-push,
    `rm -rf`, and `DROP TABLE` patterns simultaneously, since `grep`
    matches per line by default and a pattern's tokens split across a
    real newline never share one line. Fixed by flattening embedded
    newlines to spaces before any pattern runs. The documented Claude Code
    JSON shim likely wasn't exposed to this (it extracts `command` in a
    way that leaves JSON's `\n` escape as literal text), but a shell-level
    `preexec`/`DEBUG`-trap wrapper capturing a real multi-line command
    verbatim was.
  - Re-verified: all 14 original bypass repros plus these 9 new ones now
    block (23/23), and 14 legitimate commands — including
    `` confirm -rf / `` (checking the new "rm" word-boundary match doesn't
    fire on a word that merely contains "rm") — still pass clean.
- **`safety/safety-guardrail.md`**: its own verification instructions
  called `git push --force` "harmless... won't do anything unless it's
  actually allowed through" — true only if the deny list has no gaps,
  which it just turned out to have three of. Now instructs testing
  against a scratch repo, the same isolation `secret-scan.md`'s parallel
  section already requires.
- **The exact bug 1.13.1 fixed had already recurred, in `CHANGELOG.md`
  itself.** That entry's own prose quoted a literal worked example of the
  URI-with-embedded-credentials shape, twice, while narrating the
  original bug — and `scripts/detect-secrets.sh --file CHANGELOG.md`
  blocked on it. Reworded both spots to describe the shape instead of
  giving a literal matching example, then re-scanned every `.md` file in
  the repo (not just the two known spots) to confirm nothing else
  recurs — 0 flagged.
- **`autonomy/roles.md` — Bug Hunter was tagged the wrong model tier.**
  1.14.0 tagged it *implement*, but `core/engineering-loop.md` step 4
  names "Bug Hunter re-running the repro" as the independent-verification
  pass for a bug fix — the exact persona the tier system is supposed to
  protect from running on a weaker model. Retagged *verify*, per this
  file's own rule that a persona doing both jobs takes the stricter tag;
  `public-repo/install.sh`'s persona list updated to match. Also fixed a
  separate, pre-existing error in the same file: the "who needs read vs.
  write access" line listed Bug Hunter as read-only, though
  `bug-fix.md`'s fix step plainly needs write access — Manual/Exploratory
  Tester (actually read-only per its own section) had been left off that
  line entirely.
- **`autonomy/standing-permission.md` claimed its floor was "`AGENTS.md`
  rule 5 verbatim"** — it wasn't: "protected branch" had been folded into
  a redefined "shared," and "publishing" had been narrowed to "publishing
  a package," both real scope gaps in the one file that makes the
  strongest fidelity promise. Now actually quotes rule 5's list
  unchanged.
- **`README.md`'s "no product identifiers" design rule contradicted
  1.14.0's own humanizer reference** (and, on a literal reading, several
  tool names — `madge`, `whisper.cpp`, `ffmpeg` — already used elsewhere
  in this repo). Clarified the rule's actual target: identifying the
  adopting company/client/person, not naming a genuine public tool or
  reference.
- **`autonomy/roles.md`**: documented the exact env-var naming
  transformation for per-persona model overrides (previously only
  derivable by reading `install.sh`'s source), since a wrong guess fails
  silently by falling through to the tier default.
- **`mapping/database-mapping.md`**: step 8 cited the wrong
  `codebase-mapping.md` step for "verify every claim" (said step 4, meant
  step 5) — fixed. Also: step 1's staleness check assumed every table doc
  records the commit/migration it was verified against, but no step
  actually instructed writing that down — added it to step 8, mirroring
  `codebase-mapping.md` step 4's existing instruction.
- **`change-types/refactoring.md`** cited `quality/frontend-testing.md`
  step 8 for the manual/exploratory-pass check — correct when originally
  written, stale after several steps were inserted ahead of it since;
  the real content is now at step 12. Updated.

**Verified for real:** the full block-dangerous.sh/detect-secrets.sh
regression suite (23 block cases + 14 pass-through cases + 6 secret-scan
cases, 43/43) was re-run after every script change, not just the specific
repro that motivated it. The repo-wide cross-reference resolver and a
repo-wide self-scan of every `.md` file against `detect-secrets.sh` both
came back clean after all fixes.

## 1.14.0 — 2026-09-11
Two additions, both new content rather than fixes to existing playbooks:

- **`autonomy/roles.md`**: tagged each of the six personas (and the
  "defining your own role" template) as *verify* or *implement* — a
  verify-tagged role catches what someone else got wrong and should run
  on at least as strong a model as whatever it's checking; an
  implement-tagged role does work a verify pass independently re-checks,
  so a lighter/faster model is fine there without weakening the system's
  actual safety property. The tagging is advisory text, not a literal
  model name — see `public-repo`'s installer changelog for the concrete
  Claude Code wiring (a `model:` field per generated sub-agent, with
  per-persona/per-tier/all-one-model overrides), which is the part that's
  actually tool-specific.
- **`quality/writing-style.md`**: named five specific "AI writing" tells
  this file's existing rules gestured at but didn't call out explicitly
  (a not-X-but-Y contrast, a staged run-up opener, a one-line dramatic
  closer, a triad reached for by rule, arguing with an objection nobody
  raised), and added a reference to
  [github.com/blader/humanizer](https://github.com/blader/humanizer) (MIT)
  for a deeper catalog with worked rewrites — a follow-up pass, not a
  dependency this playbook needs to function on its own.
- **`AGENTS.md`**: elevated `quality/writing-style.md` to a numbered core
  principle (7), the same tier as the destructive-action and secret
  rules — it's the one playbook whose scope is genuinely universal (every
  report, comment, and doc from every playbook, not one task type), but
  it previously only lived in the flat playbooks table and a mention
  inside `engineering-loop.md` step 6, meaning a tool that reads only the
  numbered principles never saw it. Also added an explicit pointer to it
  in `core/bug-fix.md` and `core/feature-development.md`'s own Report
  steps specifically, since those two are the most likely to be pasted
  standalone rather than reached through the router.

**Verified for real:** the repo-wide `*.md` cross-reference resolver
(now covering `AGENTS.md` too) still comes back clean — 0 broken links
across 40 files — after all of the above.

## 1.13.1 — 2026-09-11
End-to-end testing of 1.13.0's fixes (real git commits through the actual
pre-commit hook, the Claude Code hook shims fed real JSON payloads, and
`install.sh`'s Skill-generation logic run against the real tree) caught
one real regression 1.13.0 itself introduced and unit-testing the script
in isolation had missed:

- **`scripts/detect-secrets.sh` blocked commits to itself.** The new
  connection-string pattern's own descriptive name/comment (a literal
  worked example of a URI with a username and password embedded before
  the host) was itself shaped exactly like the thing the pattern detects,
  so scanning `detect-secrets.sh` (or
  `safety/secret-scan.md`, which described the same pattern in prose the
  same way) against its own new rule matched and blocked the commit —
  caught by literally staging the script in a scratch repo and running
  the real pre-commit hook, not by reasoning about the regex. Reworded
  both to describe the shape (a username/password embedded in a URI's
  authority section) without a literal matching example. Re-verified: the
  script and the doc file now both pass their own scan, and the same
  real/fake-secret detection behavior from 1.13.0 is unchanged.

**Verified for real:** a scratch git repo with the actual pre-commit hook
installed — committing the hook's own script (now passes), staging a
fake-but-real-shaped secret (still rejected), removing it (commit
succeeds), and an ordinary follow-up commit (never blocked). Also fed the
Claude Code hook shims (`claude-code-secret-hook.sh`, both the `jq` and
`python3`-fallback paths, and `block-dangerous.sh`'s documented JSON
extraction pipeline) real `PreToolUse`-shaped payloads end to end, and ran
`install.sh`'s actual Skill-generation logic against the real, current
`agent-playbooks/` tree (34/34 files produced a well-formed
`SKILL.md` with a resolvable pointer path, including the ones whose
`Trigger` text 1.13.0 changed).

## 1.13.0 — 2026-09-11
A self-audit pass: applied `core/engineering-loop.md`'s own discipline
(reproduce/confirm a finding before fixing, verify independently after) to
the playbook set itself. Five parallel reviews, each covering a different
folder, surfaced roughly 30 real gaps; every one was independently
re-confirmed before being fixed, and every fix was independently re-read
afterward against the diff, not just trusted from the pass that made it.

- **`AGENTS.md`**: fixed 8 links still pointing at the pre-1.12.0 flat
  paths (`agent-playbooks/project-bootstrap.md` etc.) that the 1.12.0
  reorg's own link check should have caught but didn't. Canonicalized
  rule 5's destructive-action list (it had drifted into three different
  wordings across `AGENTS.md`, `core/engineering-loop.md`, and
  `autonomy/standing-permission.md`) and made explicit that an ordinary
  push to your own feature branch isn't gated by it, while merging/pushing
  to a shared branch is.
- **`scripts/block-dangerous.sh`**: closed several confirmed bypasses —
  `git push origin main --force` (force-push with a remote/branch named,
  the way anyone actually types it), `rm -r -f /` and `rm -rf
  --no-preserve-root /` (split/extra flags), lowercase `drop table`, and a
  raw disk-device overwrite (`dd ... of=/dev/sda`, `> /dev/nvme0n1`) all
  previously passed through silently. Re-verified against the exact bypass
  commands (now blocked) and a false-positive control set of ordinary
  commands (still pass) — 25/25.
- **`scripts/detect-secrets.sh`**: added a vendor-agnostic pattern for a
  connection string with a username and password embedded before the
  host (a generic Postgres/Redis/Mongo-style `DATABASE_URL` previously
  passed through untouched, since the scanner only recognized specific
  vendor token shapes).
- **`quality/docs-sync.md`**: a security/validation/data-integrity claim
  that disagrees with current code no longer gets auto-classified as
  "drift" and rewritten to match — that path could silently launder an
  actual regression into documented, "correct" behavior.
- **`core/bug-fix.md`, `core/feature-development.md`,
  `quality/code-review.md`**: made independent verification an explicit,
  disclosed step — "the implementer's own re-run" is no longer allowed to
  quietly stand in for a separate pass, and a reviewer with no execution
  access now says so instead of accepting whatever log gets pasted back.
- **`change-types/incident-response.md`**: checks for a preceding schema
  migration before defaulting to rollback (rolling back code alone after a
  contract-stage migration can fail the same way or worse), and gives
  "active user impact" an operational definition instead of leaving the
  incident/bug-fix split to unguided judgment.
- **`quality/security-review.md`**: now traces new/changed input into
  *unchanged* sinks, not just changed lines; a real secret is reportable
  regardless of a demonstrated exploit chain.
- **`core/engineering-loop.md`**: disambiguated performance-vs-bug-fix and
  code-review-vs-architecture-review routing with concrete triggers
  instead of "significant"/"regression" left to guesswork.
- Assorted fixes to `change-types/release.md` (fix the degraded threshold
  before rollout, not during), `dependency-upgrades.md` (removed a
  "routine maintenance" carve-out that contradicted its own anti-pattern),
  `database-migration.md` (contract-stage sign-off is mandatory, not a
  judgment call), `project/project-audit.md` (Find phase now includes
  dependency/performance checks), `project/project-bootstrap.md` (records
  a baseline pass/fail state so later "no regression" checks have
  something real to diff against), `mapping/codebase-mapping.md` and
  `mapping/database-mapping.md` (staleness checks now cover recorded
  dependencies too, plus a data-sampling step and a migration-replay
  caveat), `mapping/third-party-api-integration.md` (read-only
  classification is provisional until a real call confirms it),
  `autonomy/mission-mode.md` and `autonomy/roles.md` (named the
  honor-system limits explicitly instead of implying more enforcement
  than exists), `safety/sensitive-data.md` (states plainly it has no
  backing script, unlike `safety-guardrail.md`/`secret-scan.md`),
  `quality/architecture-review.md`, `quality/observability.md`, and
  `quality/frontend-testing.md` (each got an explicit fallback for the
  case its main check assumes a capability — a dashboard, a browser, a
  named forcing constraint — that may not actually be there).

`public-repo/` (the separate installer distribution) was not touched by
this pass.

**Verified for real:** the two script fixes were tested against the exact
bypass commands found (all now correctly blocked) plus a false-positive
control set of legitimate commands (all still pass) — not assumed correct
from reading the regex. Every markdown diff was re-read after being
written, cross-checked for new contradictions against neighboring files,
and the repo-wide `*.md` cross-reference resolver was re-run afterward
(0 broken links across 41 files, `AGENTS.md` included this time).

## 1.12.0 — 2026-09-09
Moved 8 playbooks that sat loose at the repo root — with no folder of
their own despite the README's own stated design ("grouped into folders
by kind of concern") — into three new category folders alongside the
existing `core/`/`quality/`/`change-types/`/`autonomy/`/`safety/`:

- **`project/`** — whole-project passes: `project-bootstrap.md`,
  `project-audit.md`
- **`mapping/`** — documenting what already exists from real evidence:
  `codebase-mapping.md`, `database-mapping.md`,
  `third-party-api-integration.md`
- **`media/`** — turning a recording/document into verified findings, or
  generating one: `demo-video.md`, `video-review.md`, `doc-review.md`

Every cross-reference to and from these 8 files, across every other
playbook, `README.md`, and `EXAMPLES.md`, was updated to the new path —
checked with a small script that resolves every backtick-quoted `*.md`
reference in the repo against the real filesystem, not just grepped by
eye. That check also caught and fixed two unrelated, pre-existing broken
references it turned up along the way (a bare `bug-fix.md` in
`EXAMPLES.md` missing its `core/` prefix, and a bare `core/engineering-
loop.md` in `quality/frontend-testing.md` missing the `../` a
cross-folder reference needs) — left in rather than silently dropped,
since the check exists to catch exactly this class of drift. Also fixed
a real gap the same audit surfaced: `project-audit.md` was never listed
in `README.md`'s "What's in here" section at all, despite existing and
being referenced from three other files — it's now listed under
`project/` along with everything else that moved.

Historical `CHANGELOG.md` entries below still reference these files by
their old, pre-move paths — left as-is, since a changelog is a record of
what was true when each entry was written, not a document to keep
synced with the current tree.

**Verified for real:** every one of the ~100 cross-reference edits was
checked, not assumed — the resolver script above ran clean (0 broken
references) after all fixes, run from the repo root against every `.md`
file except this changelog.

## 1.11.0 — 2026-09-09
Added locator/query-definition organization and shared-logger requirements
to both `quality/frontend-testing.md` (step 14) and
`quality/backend-testing.md` (step 8), prompted by auditing a real
frontend + backend test-suite pair against exactly this question and
finding both already followed the intended pattern but neither wrote it
down:

- **Locators (frontend) / query-and-mutation definitions (backend) live
  in exactly one place, chosen once for the whole suite** — either as
  properties/methods on a page object (or a dedicated module per domain
  on the backend side), or pulled out into a separate locator/query
  module per page or domain. Either is legitimate; mixing both
  conventions in the same codebase, or a spec file building a raw
  locator/query inline instead of going through the chosen layer, is the
  same "invented a new style" problem either playbook already calls out
  elsewhere.
- **Logging goes through one small shared logger utility, reserved for a
  genuine "a human may need to act on this" moment** — a record the
  suite created against real data that it has no way to clean up
  itself — not routine progress narration, and not a substitute for the
  test runner's own reporter/trace output.

**Verified for real:** ran this exact audit against a real frontend
(page-object) and backend (query-module) test-suite pair. Both already
kept locators/query definitions in one consistent place; a shared logger
was added to both and exercised for real, including a genuine use case —
a test that uploads a file through a REST endpoint with no corresponding
delete/cleanup API, where the logger now flags the resulting orphaned
record instead of leaving it unexplained. The audit also surfaced two
unrelated, real findings worth recording here since they were found
*because* of doing this refactor properly rather than skipping straight
to "looks fine": a previously-passing assertion about one entity's
soft-delete behavior was wrong (it stayed visible with a flipped status
in the earlier pass by coincidence of an optimistic UI update's timing
window, not because that's the real, confirmed contract — the real
contract, confirmed against the API directly, is that the row disappears
from the list entirely), and a create-record mutation was found to
return a server-side 500 for its own plain, schema-valid minimal input,
confirmed independently from both the UI and the raw API — both now
tracked as known, currently-reproducing bugs via each suite's existing
`test.fail()` convention rather than left silently broken or masked by
a wider timeout.

## 1.10.0 — 2026-09-09
Added three boundary-condition categories to `quality/backend-testing.md`
step 3 that the 1.9.0 pass against a real client's backend didn't cover,
found by asking "what's still missing" after that pass rather than
assuming it was complete:

- **Cross-tenant data isolation**, named as its own boundary condition
  distinct from plain authentication — a request can carry a perfectly
  valid token and still be a bug if it reaches another tenant's data.
  Explicitly requires two real accounts/tenants to test at all; a suite
  authenticating as only one account structurally cannot catch this
  class of bug (an IDOR).
- **Rate limiting**, where an API states or implies one (a documented
  limit, or a response header like `X-RateLimit-Remaining`) — a header
  reporting a shrinking quota is not proof the limit is actually
  enforced; only exhausting it and checking the request that should be
  rejected proves anything.
- **Pagination boundary values** (zero limit, offset past the last page,
  negative values) and pagination stability under a changing data set —
  named as the same out-of-order/race family `frontend-testing.md` step
  12 already covers for a rapid filter change, one layer down at the
  query itself.

Three matching anti-patterns added (a single-tenant test suite, trusting
a rate-limit header over exhausting the limit, testing pagination only
in-range).

**Partially verified:** the rate-limiting category is grounded in real
evidence already captured against that same client's API during the
1.9.0 pass (a login response carrying real `x-ratelimit-remaining`/
`-limit`/`-reset` headers) — not invented for this entry. Tenant
isolation and pagination-boundary testing have not yet been run for real
against that project's own dedicated backend test repo specifically
(it currently authenticates as a single superadmin account throughout)
— the natural next step if asked for.

## 1.9.0 — 2026-09-09
Extended `quality/backend-testing.md` with the same manual-pass →
evidence-backed report → codify-into-test-code shape `frontend-testing.md`
got in 1.8.0, plus explicit REST/OpenAPI-vs-GraphQL coverage it didn't
have before at all:

- **Step 1** now names REST-with-OpenAPI/Swagger and GraphQL as distinct
  paradigms with different sources of truth (a spec file vs. a schema/
  introspection query) and different failure shapes — concretely, that a
  GraphQL response can be `200 OK` with the real error sitting in a
  populated `errors[]` array rather than the status code, and that an
  N+1 resolver is a real defect a plain response-shape check won't catch.
- **New steps 7–8** (existing 7–8 renumbered to 9–10) add the manual/
  exploratory pass this playbook had no equivalent of before: hit the
  real endpoint directly, capture actual request/response evidence, turn
  it into `frontend-testing.md` step 13's same report shape, then codify
  into real test code under `frontend-testing.md` step 14's same
  senior-engineer bar and where-should-it-live question — cross-linked
  rather than re-derived, since the shape is identical one layer down.
- Three new anti-patterns (status-code-only GraphQL error checking, a
  hand-maintained REST test duplicating an OpenAPI spec instead of
  running it, reporting a documented placeholder as a new bug) and a
  GraphQL-specific "first time" onboarding paragraph.

**Verified for real, including the new steps 7–8:** ran this process
against a real client's live GraphQL backend end to end — introspected
the real schema directly (`__schema`/`__type`, not guessed from the
frontend's source), hit real queries/mutations for auth and that
project's core entities, then built and ran a 23-test suite in its own
dedicated backend-test repo against that same API. One real mistake was
caught and fixed by running it for real, not assumed correct from the
diff: a guessed list-filter argument name turned out to be wrong for one
of the two entity types tested, found via the real `BAD_USER_INPUT`
error the wrong guess produced. Real findings this verified: auth
failures return HTTP 200 (the real error lives in the response body, not
the transport status); a GraphQL response's `data` key is `undefined`
for a validation-phase failure but `null` for an execution-phase one —
two genuinely different absent-shapes, not one; a unique-field
constraint holds under a real concurrent-create race fired via
`Promise.all`; and one entity's soft-delete disappears entirely from its
list query while another entity's soft-delete stays visible with status
flipped — a real inconsistency between the two. Staging was checked for
and cleared of leaked test data before finishing.

**Step 1's REST-vs-GraphQL distinction has since been verified against a
real REST endpoint too**, not left as a GraphQL-only claim: the same
client's backend exposes one plain REST route alongside its GraphQL API
(a multipart file-upload endpoint — GraphQL has no native way to do
that), with no Swagger/OpenAPI spec exposed for it at any common path.
Testing it confirmed real, meaningful HTTP status codes (401/400/201) —
a genuinely different failure shape than the GraphQL side's
always-200 — and confirmed step 1's "no spec exists yet, derive the
matrix from the real code" fallback is exactly the right call for an
endpoint like this, not a hypothetical case. One more real bug was found
and fixed in the course of this: a test config that forced
`Content-Type: application/json` onto every request broke the multipart
endpoint's own boundary header, producing 500s instead of the real
statuses being tested for — removed, since a request library's own
per-payload-type default was already correct.

## 1.8.0 — 2026-09-08
Extended `quality/frontend-testing.md`'s manual/exploratory-pass step
(step 12) with three new steps and a code-quality bar, verified end to
end against a real client's app (a fleet-management CMS) and its real
staging environment — not reasoned about in the abstract:

- **Step 12** now also captures network/API request-response evidence
  (operation name, request, real response/error) alongside screenshots,
  not screenshots alone.
- **Step 13** turns a manual pass into an evidence-backed report (steps
  followed, flow-by-flow results, API evidence, bugs with repro +
  suggested fix, suggestions kept separate from bugs) — matching
  `video-review.md`/`doc-review.md`'s existing report shape instead of
  inventing a new one. Explicitly calls out checking the source for a
  `TODO`/placeholder marker before reporting something as a bug.
- **Step 14** codifies a manual pass into real automated test code:
  ground locators/assertions in the actual source (query names,
  validation rules, whether a stable identifier already exists) rather
  than the rendered page alone; follow or propose a test structure;
  design tests to create-and-clean-up their own data against a real
  shared environment; don't let a known backend gap masquerade as a
  passing green test; run it for real and capture actual pass/fail
  output. Includes a concrete senior-engineer code-quality bar (strong
  typing, no duplicated logic/magic strings, deliberate logging, no dead
  scaffolding) cross-linked to `code-review.md`'s existing convention-
  adherence check rather than duplicating it. Also codifies where new
  test code should live: a black-box suite that never imports the target
  app's own source has no real reason to be bolted onto that app's
  `package.json`/dependency tree — decide and say so explicitly rather
  than defaulting into the app repo unasked.
- Two new anti-patterns (reporting a UI-only symptom when network
  evidence was equally available; asserting a placeholder data layer as
  "passing").
- **Step 12** also now names four concrete categories to deliberately
  check beyond the happy path — boundary values, error/failure states,
  unusual sequences (double-submit, back-navigation, acting on a record
  a different action just changed), and permission/role boundaries — and
  **step 14** requires carrying whichever of those a manual pass actually
  found into the automated suite as their own tests, not just into the
  step-13 report where they'd otherwise evaporate once the report is
  closed.
- **Step 12** also names concrete responsive-testing breakpoints (mobile/
  tablet/desktop) instead of "check it looks right," and calls out that a
  non-functional mobile-nav toggle is a defect that only exists at a
  narrow viewport and is invisible if every check runs at one default
  width.
- **Step 14** no longer assumes every flow is CRUD-shaped: it now names
  six other flow shapes explicitly (multi-step wizards, read-only
  dashboards, search/filter UIs, file upload/download, real-time/
  streaming, background/async jobs, and largely static/CMS-templated
  sites like WordPress) and says to model each on its own actual
  interaction shape rather than forcing a create/delete template that
  doesn't fit. It also now says to match the target app's *existing
  build/lint toolchain* (Babel/SWC/tsconfig, linter, module system), not
  just its test-runner/directory shape, when new test code lives inside
  that app's own repo — cross-linked to `code-review.md`'s existing
  "don't invent a new style" convention-adherence check rather than
  restating it, and explicitly scoped to not apply to a separate
  dedicated test repo (which shares no build step with the app at all).
- **Step 4** now names animated/transitioning elements explicitly: a
  "visible" DOM node mid-transition isn't the same as one at its resting
  state, so wait for the real end-of-transition condition
  (`transitionend`/`animationend`, or the driven property's final value)
  before asserting or screenshotting — the same "presence isn't ready"
  rule step 4 already applied to disabled→enabled transitions, extended
  to animation.
- **Step 12**'s edge-case list gained two more real, specific cases: a
  filtered/searched/sorted listing's classic out-of-order-response race
  (changing the filter twice quickly, where an earlier request resolves
  *after* a newer one and silently overwrites its correct result with a
  stale one); and, for a page with multiple independent listings/widgets
  (a homepage with several panels, a multi-chart dashboard), checking
  that acting on one panel actually stays scoped to it rather than
  leaking into another's state or requests.
- **Step 9** now covers CSS-effect-driven components (a horizontal-scroll
  card carousel, a sticky/blurred nav bar, a glass/frosted panel) as
  their own class: their pixel appearance is a visual-regression concern
  like any other, but each also hides a real functional risk a
  screenshot won't catch — a decorative blur/glass layer with no
  `pointer-events: none` silently swallowing real clicks, a carousel's
  boundary/scroll-snap correctness, and off-screen carousel content
  staying keyboard-focusable when it shouldn't be.
- **Step 8** now names the standard form controls concretely instead of
  leaving "keyboard operability" abstract: text inputs (match the label-
  derived accessible name, not placeholder text, which disappears on
  input), dropdown/custom-combobox (real keyboard operability, and not
  rendering the selected value twice in a way that's ambiguous to
  select — the exact strict-mode collision this session's own worked
  example hit on its first real run), radio groups (genuinely one
  group, not independently-toggleable checkboxes styled as radios), a
  "select all" checkbox's indeterminate state, and a submit button that
  actually disables mid-request rather than just showing a spinner a
  fast click can still get through.

**Verified for real, not just written:** ran this updated process against
that client's staging CMS end to end — logged in, exercised that app's
core entity CRUD flows, captured real GraphQL request/response evidence
(including catching and correcting two of the model's own first-pass
conclusions once checked against the actual API payload and source: a
misread status field that turned out to be an unrelated field, and a
"missing section" that turned out to be role-conditional application
code, not a bug), found and documented five real bugs (a
delete-confirmation dialog naming the wrong entity, a role-conditional
missing UI section, non-decrementing dashboard counts, misleading
"permanent" delete copy, a missing Edit button), then built a Playwright
suite covering those entities and a set of known-placeholder routes in a
newly created, separate repo per the new step-14 guidance above. Two real
bugs surfaced *in the test code itself* while running it for real — a
hydration-race false negative on empty-form submission, and a strict-mode
locator collision on a duplicated dropdown option — both fixed and
re-verified by re-running, not assumed fixed from reading the diff. Final
state: 20/20 tests passing, confirmed from the suite's final repo
location (re-run after the move, not assumed to still work), with a
clean `tsc --strict` pass and zero ESLint-equivalent dead code.

## 1.7.0 — 2026-09-08
Extended `quality/frontend-testing.md` and `quality/backend-testing.md`
with lessons drawn directly from a real QA report review earlier in this
project (via `doc-review.md` against a real mobile app and its real
Katalon test suite) — codified as tech/platform-agnostic testing
discipline, not tied to that framework.

`frontend-testing.md`: three new steps plus anti-patterns —
(1) wait for the actual interactable state (visible *and* enabled), not
just presence, since a disabled→enabled transition can rebuild the
underlying element and invalidate an earlier reference; (2) prefer a
stable, purpose-built locator (a real accessibility identifier/
`data-testid`) over a positional/structural one, on web *or* native
mobile (Appium/Katalon) — a testability gap to raise with development,
not to route around; (3) don't assume a screen/list looks the same after
an action as before it (a redeemed/removed/reordered item), and watch for
an accidentally duplicated step targeting the same just-navigated-away
element. Also fixed a pre-existing, unrelated bug in this same file: the
"Who uses this" section referenced step numbers that no longer matched
the actual steps (calling out "step 4's accessibility check" when
accessibility was actually step 5) — rewritten to describe the read/write
split qualitatively instead of hardcoding step numbers that renumber
easily.

`quality/backend-testing.md`: two additions — (1) test the *second* call
of an idempotent/one-time operation explicitly (a coupon redemption, a
charge, a queue handler), not just the first, since only the repeat call
proves whether a side effect double-applies; (2) wait on the real
completion condition for anything asynchronous (poll status, wait on the
real event) rather than a fixed sleep, and treat "passes standalone,
fails as part of the full suite" as the specific, concrete symptom of
test-order/state dependency rather than something to retry away.

Prose-only additions (no scripts to run) — reviewed for consistency and
correct internal step-number cross-references throughout both files
after renumbering, not executed.

## 1.6.3 — 2026-09-08
Fixed `scripts/record-screen.sh` (`demo-video.md`'s screen-recording
step): `-pix_fmt yuv420p` placed before the output path is read by
avfoundation's demuxer as an *input* capture-format request on some
hardware, and can fail outright there since avfoundation only offers
uyvy422/yuyv422/nv12/0rgb/bgr0 as capture formats — found on real
hardware by actually running it and getting a silently-empty output
file, not assumed from the docs. Moved it to an explicit output-side
`-vf format=yuv420p` filter instead, which can't be misread as an input
request, in both the `start` and `timed` code paths.

Verified: syntax-checked, then run for real on macOS (`timed` mode,
`-f avfoundation`, real screen-capture hardware) — produced a valid
h264 recording with real, non-blank screen content (confirmed by
extracting and viewing a frame). Compared directly against the old
`-pix_fmt`-before-output command on this same machine: both produced
valid output here, so the specific failure this fixes did not reproduce
on this hardware/ffmpeg build (avfoundation here already falls back to
a supported pixel format gracefully regardless of placement) — this
fix addresses a real, hardware-dependent failure mode observed
elsewhere, confirmed not to regress anything on this machine, but not
independently reproduced-then-fixed here the way the rest of this
CHANGELOG's entries are.

## 1.6.2 — 2026-09-08
Sharpened `doc-review.md` step 2's guidance with a concrete trigger,
found immediately after 1.6.1 shipped, on the same real 146-page QA
report: a test case (`Redeem_by_activity`) reported overall status
"ERROR" while every one of its visible steps read "PASSED," with the
trail simply stopping. Following 1.6.1's new guidance (render the whole
page range, don't trust `sparse` alone) surfaced the real cause: two
uncaptioned screenshots showing the same voucher code first successfully
redeemed, then — about a minute later, same test run — hit again and
met with an "Already redeemed" screen. Correct app behavior (you can't
redeem the same voucher twice); wrong test behavior (re-selecting the
same voucher instead of moving to the next one, likely because the list
re-renders after a redemption and the test's item-selection locator isn't
robust to that). Added the specific trigger to step 2: a section's
overall status not matching what its visible steps show is itself the
signal to render that section's full page range, not a dead end.

## 1.6.1 — 2026-09-08
Fixed a real gap in `doc-review.md`'s step 2, found during actual
production use (not synthetic testing this time): reviewing a real
146-page third-party QA/test-run PDF against a real Flutter codebase, a
specific failure's evidence turned out to be two embedded screenshots
with **no caption text next to them at all** — common in QA reports,
where some screenshots are captured automatically (on failure, or at a
teardown/listener point) rather than via a scripted step that prints
"Screenshot is taken." The `sparse` page-image heuristic (average
non-space characters per page) never flagged these pages, because the
page still had plenty of *other* text (running headers, table column
labels) — `sparse` measures page-level text density, not "does this
specific screenshot have a caption," so it can't and shouldn't be
expected to catch this case. Fixed by changing the guidance, not the
scripts (both were working correctly): once investigating a specific
finding in depth, always render every page across that finding's entire
page range explicitly, rather than trusting `sparse`'s verdict alone to
decide whether an image is worth seeing.

## 1.6.0 — 2026-09-08
Added `doc-review.md` + `scripts/extract-doc-text.sh`,
`scripts/render-doc-pages.sh`, `scripts/doc-page-index.sh` — the same
pipeline as `video-review.md` applied to a document instead of a
recording: extract text (`pdftotext` for PDF, `pandoc` for DOCX/ODT/RTF/
HTML/etc.), optionally render scanned/visual pages as images, draft
findings (summary/key points/queries raised/action items split fix-vs-
build), re-verify each one against the actual text/page evidence, then
optionally route each action item to `core/engineering-loop.md` one at a
time. Also added **token-bounded processing for large inputs, on both
playbooks**: `extract-media.sh`'s frame interval now defaults to `auto`
(duration ÷ 120 frames, floored at 3s) instead of a fixed 5s, so a 4-hour
recording and a 12-second one both land around ~120 frames instead of
however many a fixed interval happens to produce; `doc-page-index.sh`
gives line-number-per-page boundaries so a several-hundred-page document
can be read in ~20-page chunks (matching a common hard limit on how much
a single file-read call will return for a PDF) instead of loading it
whole. Both playbooks' "read the evidence" step now explicitly describes
processing long input in bounded batches with compact per-batch notes
carried forward, not the raw batches themselves.

Tested directly on macOS. `extract-doc-text.sh` against: a real PDF (via
`cupsfilter`), a real `.docx` and `.rtf` (via macOS `textutil` → `pandoc`,
extraction matched the source exactly modulo whitespace), a real `.md`
copy-through (byte-identical), and a **real 146-page, 10MB third-party
PDF** (a Katalon mobile-app test report, not synthetic) — extracted
cleanly in under a second. Two real bugs were found and fixed during this
pass: the sparse-page-warning math was off by one (assumed pdftotext's
per-page form-feed meant "N feeds ⇒ N+1 pages"; direct byte inspection of
both the 146-page doc and a real scanned 1-page PDF showed it's already
one feed per page including the last, so no +1 — fixed and re-confirmed
on both); and `render-doc-pages.sh` produced double-suffixed filenames
(`page_0001-001.png`) because `pdftoppm` appends its own page number even
for a single-page render — fixed with `-singlefile`, re-confirmed across
its explicit-list/`all`/`sparse` modes. `doc-page-index.sh`'s page→line
mapping was checked directly against real file content, not eyeballed.
`render-doc-pages.sh`'s `sparse` mode correctly rendered zero pages
against the 146-page doc (verified via `pdfimages -list` that its
screenshot pages all carry substantial surrounding text, a true negative,
not a bug). Chunked reading of that same 146-page document was performed
for real (not just designed): read in 20-page chunks from
`doc-page-index.sh`'s own output, surfacing a real finding (the report's
own pass/fail summary and specific failing/erroring test case names) with
a targeted re-read later in the document landing exactly where the index
said it would. No content from this real third-party document is quoted
at length or committed anywhere in this repo — only the structural facts
needed to demonstrate the mechanism works. A full run through
`core/engineering-loop.md` was also done, real not simulated: the same
`add_tax` throwaway-repo scenario from `video-review.md`'s own
verification, this time driven by a synthetic PDF — reproduce → fix →
verify, with a real failing-then-passing pytest run and a real diff.
`extract-media.sh`'s new `auto` interval was verified against a genuinely
4-hour-long synthetic video (tiny resolution/frame rate, so fast to
generate): correctly computed a 120s interval and extracted exactly 120
frames, confirmed by counting the actual files, with both audio and frame
extraction finishing in under 30 seconds — transcribing that much audio
was not attempted (whisper's own runtime scales with duration regardless
of this script, and the synthetic audio had no real speech to transcribe
anyway), which is now stated explicitly rather than left implied. Not run
on Linux/Windows directly (no such environment available); all three new
scripts are the same plain POSIX-bash + real-CLI-tool shape already
exercised cross-platform-honestly elsewhere in this repo.

A further re-verification pass (prompted by user request, after the
above had already shipped in this same working state) found two more
real bugs, fixed before anything was committed. In `extract-media.sh`:
`frame_last.png` could silently fail to be written at all while the
script still reported success — `ffmpeg` seeking to `duration - 0.15s`
for one frame can produce zero output and no file while still exiting 0,
confirmed on real clips as short as 3s and as long as 60s, not an exotic
case. Fixed with a bounded retry at increasing margins (0.5/1/2/4s) and
an explicit file-existence check instead of trusting the exit code;
re-confirmed on the exact clips that exposed it, plus the
"interval-divides-duration-exactly" arithmetic shape the earlier 4-hour
test also hits (checked with a 30s/10s-interval equivalent, since
re-running the full 4-hour generation again wasn't warranted for this).
In `extract-doc-text.sh`: the file extension was detected from the full
path instead of the basename, so a dotted parent directory (e.g. a
`v2.0/` version folder) corrupted detection for any extensionless file
inside it — confirmed directly (`v2.0/README` misread as extension
`0/readme`) and fixed by extracting from `basename` instead.

## 1.5.0 — 2026-09-08
Added `video-review.md` + `scripts/extract-media.sh`, `scripts/transcribe.sh`
— the reverse pipeline of `demo-video.md`: extract audio/frames from any
recording ffmpeg can read, transcribe locally (whisper/whisper.cpp, with a
documented graceful degrade when neither is installed), draft findings
(summary/key points/bugs/asks), then re-verify each one against the actual
transcript/frame evidence before handing it to the user, with asks
optionally routed to `core/engineering-loop.md` one at a time.

Tested directly on macOS, including a full synthetic run through
`core/engineering-loop.md`: built a real bug-report video (genuine spoken
narration via `say` describing a defect, plus rendered on-screen frames
showing the buggy code and a failing test), ran it through
`extract-media.sh` → `transcribe.sh` (no STT engine installed, degraded
exactly as documented) → read the extracted frames directly → drafted and
re-verified findings from that frame evidence alone → handed the resulting
"fix" ask to `core/bug-fix.md`'s reproduce → fix → verify sequence in a
throwaway repo, independently re-reproducing the failing test before
touching code, then confirming both the targeted test and the full suite
passed after the fix. A re-verification pass over the scripts themselves
(prompted by user request) also caught and fixed two real bugs before any
of this shipped: `extract-media.sh` didn't clear `frames/` before
re-extracting, so a re-run with a different interval (or a swapped-in
audio-only input) left stale frames from the previous run mixed in
silently; `transcribe.sh`'s `whisper` (openai-whisper) branch swallowed
both stdout and stderr, so a real failure there (bad audio, a failed model
download) would have died with zero explanation, contradicting this repo's
own no-silent-failure convention. Both are fixed and re-tested (including
a forced-failure case proving the error now surfaces, and a stand-in
success case proving the output-file move logic still matches the real
CLI's documented naming).

The real `openai-whisper` transcription output has since been confirmed
too. The first pip install attempt failed as above (`llvmlite` tried
building from source, no wheel for the version pip picked); forcing
wheel-only resolution (`pip install --only-binary=llvmlite,numba -U
openai-whisper`) got past it, and a follow-on NumPy 1.x/2.x ABI crash on
first run was fixed with `pip install 'numpy<2'` — both now documented as
Prerequisites in `video-review.md` so the next install doesn't rediscover
them. With a working install, `transcribe.sh` was run unmodified against
real spoken narration (macOS `say`, not a synthetic tone) both directly
and through the full `extract-media.sh` → `transcribe.sh` chain, with both
the `tiny` and default `base` models, and produced an accurate transcript
each time. `whisper.cpp` remains genuinely unverified (no local build
available) — same caveat this repo already gives Piper in
`demo-video.md`. Not run on Linux/Windows directly (no such environment
available); same ffmpeg-only POSIX-bash design as the already-multi-OS
`demo-video.md` scripts.

A second re-verification pass found one more real bug: `extract-media.sh`
extracted audio unconditionally, so a video with no audio stream at all
(mic off, a muted screen capture — a realistic input, not a corrupt one)
made the whole script die on that step with a cryptic ffmpeg error,
never reaching frame extraction. Fixed the same way as the earlier
audio-only case (check for the stream first, skip and say so if it's
missing, keep going) and re-tested against a real silent clip alongside
the existing normal/audio-only/missing-file cases to confirm no
regression.

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
Replaced an external tool reference with three playbook-native
improvements to `codebase-mapping.md`/`engineering-loop.md`, closing the
same token-efficient-repeated-context problem without depending on
anything outside this project.

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
