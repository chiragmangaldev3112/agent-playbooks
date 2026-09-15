# Changelog

Every entry here corresponds to a real, tested change to the playbook
content — not a version bump for its own sake. See `agent-playbooks/VERSION`
for the currently-installed version; a fresh `install.sh` run always fetches
the latest, and now prints the version it installed.

## 1.17.0 — 2026-09-15
Added a new `README.md` section covering how a playbook actually gets
invoked once it's wired into a tool, not just how the tool becomes
aware of it — the wiring section never covered that gap. Splits the 15
supported tools into three groups: matched automatically from plain
language with no command needed (most of them, including Claude Code
and Cursor's default mode), explicit invocation by name for tools that
support it (`/name` in Claude Code and Hermes Agent, `@name` in Cursor
and Antigravity, `/skill:name` in Pi, a native Skill tool in Kimi Code/
OpenCode), and tools with no separate skill mechanism at all, where
describing the task in plain language is the only option (OpenAI Codex,
VS Code Copilot Chat). Every fact reuses research already cited in
1.16.0 — no new tool docs were fetched for this entry.

## 1.16.0 — 2026-09-15
Expanded `README.md`'s tool-wiring section from 5 to 15 supported tools —
GitHub Copilot CLI split out as its own entry, plus new entries for Codex
App, Gemini CLI, Devin CLI, Factory Droid, Grok Build, Kimi Code,
OpenCode, Pi, and Hermes Agent — each documenting whether that tool
auto-reads `AGENTS.md` and its own Skill/rule-directory convention, at
the same detail level as the original five. `AGENTS.md`'s own opening
and closing lines now name the full expanded list rather than the
original handful. Every claim was checked against each tool's current
official documentation rather than assumed, which caught two naming/
product corrections before publishing (Grok Build's actual product
name, and that Devin CLI is a distinct product from cloud Devin with its
own rules mechanism). A follow-up independent re-verification pass
caught and fixed one more real error (an unverified claim about Pi's
skill-directory support, corrected to a real one found in Pi's own
docs) and one real overclaim (a "recommended path" claim for Devin CLI
that wasn't actually supported by the source) before anything was
committed.

## 1.15.0 — 2026-09-15
Added `quality/receiving-code-review.md`, the implementer's-side
counterpart to `code-review.md`'s reviewer side: verify feedback against
the actual codebase before implementing it, resolve unclear items before
acting on any of them, and grep for real callers before building out a
"do it properly" request. Wired into `core/engineering-loop.md` step 4,
`README.md`, `AGENTS.md`, and `EXAMPLES.md`. Also added a phrasing rule
to `engineering-loop.md` step 4 against stating a completion claim
before the verification command has actually been run, and a new
section in `autonomy/roles.md` on sizing and isolating pieces of a
multi-step delegation. Verified with a controlled paired test: two fresh
subagents given an identical code-review scenario, one with this
playbook and one without — both reached the same call on two of three
items, but only the playbook-following agent correctly recognized a
dead function should be removed rather than built out further.

## 1.14.5 — 2026-09-14
Closed real, confirmed bypasses in the two enforced security scripts,
found by actually running crafted inputs through each rather than by
inspection. `scripts/detect-secrets.sh` now strips `\r` as well as `\n`,
closing a CRLF-line-ending split that let a secret token pass through
clean. `scripts/block-dangerous.sh` gained checks for indirection
bypasses that hid a dangerous command from the deny checks — `eval`/
`bash -c` of a variable, a base64-decoded payload piped to a shell,
`xargs rm -rf` with the target supplied via pipe, and a
command-substitution-hidden `rm -rf` target. Verified against the full
existing regression set with no new false positives.

## 1.14.4 — 2026-09-14
Added a "Persisted agent content" section to `safety/sensitive-data.md`,
closing a gap with `safety/memory-hygiene.md`: before writing anything
derived from a real client's system into memory, a changelog, or a
report, genericize identifying details (client/project name, staging
URLs) at write time rather than relying on a cleanup pass afterward.
Prompted by a real changelog entry that had named a specific client's
system before being corrected.

## 1.14.3 — 2026-09-11
Documentation follow-up for two features added earlier the same day:
added a worked example for the model-tiering override in
`autonomy/roles.md` to `EXAMPLES.md`, alongside a mention of the
humanizer follow-up under `quality/writing-style.md`'s existing
example, and updated `README.md`'s one-line description of
`writing-style.md` to mention the humanizer reference. No playbook
behavior changed — both features already existed; this just brought the
surrounding docs in line with them.

## 1.14.2 — 2026-09-11
A third audit pass, run in parallel across three reviewers — one
attacking the two security scripts harder than the previous round, one
re-checking the previous round's changes for regressions, one checking
`public-repo`'s consistency ahead of release. It found that 1.14.1's own
fix for target-position bypasses had introduced a real false positive —
an unrelated second command chained with `&&`/`;` could supply the
"dangerous target" half of a match on its own, wrongly blocking harmless
chained commands. Fixed properly this time by splitting a command into
clauses before any pattern runs and checking each clause independently;
also added missing home-directory target spellings (`/root`, `$HOME`,
`~/`) to `block-dangerous.sh`. Separately, `detect-secrets.sh` turned out
never to have received the newline-splitting fix `block-dangerous.sh`
got in 1.14.1 — a secret split across a literal `\n` still passed
through; fixed by stripping newlines entirely rather than flattening to
a space. Also added concrete scratch-repo verification recipes to
`safety/safety-guardrail.md` and `safety/secret-scan.md`, and fixed
stale "implement"-tier wording for Bug Hunter left over in `public-repo`'s
installer docs after 1.14.1 retagged it. Re-verified against the full
regression suite (26 block cases, 19 pass-through cases) after every
change.

## 1.14.1 — 2026-09-11
A second, harder audit pass on the post-1.14.0 state, this time
deliberately probing the two enforcement scripts with invented bypass
attempts and checking the newest additions for problems. Found and fixed
three more real `block-dangerous.sh` bypasses: a bundled short git flag
(`-fu`) not recognized as a force-push, several `rm -rf` target spellings
(`/*`, `/.`, `//`, target not immediately after the flags) that passed
through, and — more structurally — a literal embedded newline in a
command that defeated the force-push, `rm -rf`, and `DROP TABLE` checks
simultaneously, fixed by flattening embedded newlines before any pattern
runs. Also found that `CHANGELOG.md` itself had recreated the exact
secret-shaped-example bug 1.13.1 had fixed elsewhere, and reworded it;
corrected a mistagged persona in `autonomy/roles.md` (Bug Hunter should
be *verify* tier, not *implement*, per the file's own rule) along with a
stale read/write-access line in the same file; tightened
`autonomy/standing-permission.md`, which claimed to quote `AGENTS.md`
rule 5 verbatim but had actually narrowed its scope; and fixed a
misleading "harmless" claim about `git push --force` in
`safety/safety-guardrail.md`'s own verification instructions. A handful
of smaller stale cross-references were also fixed in
`mapping/database-mapping.md` and `change-types/refactoring.md`. Every
fix was independently re-reproduced, and the full
block-dangerous.sh/detect-secrets.sh regression suite (43 cases) was
re-run clean afterward.

## 1.14.0 — 2026-09-11
Tagged each persona in `autonomy/roles.md` (and the custom-role
template) as *verify* or *implement* — a verify-tagged role should run
on at least as strong a model as whatever it's checking, while an
implement-tagged role's work gets independently re-checked, so a
lighter model is fine there; the tagging is advisory text here, with the
concrete Claude Code model-tier wiring living in `public-repo`'s own
installer. `quality/writing-style.md` now names five specific "AI
writing" tells explicitly (a not-X-but-Y contrast, a staged run-up
opener, a one-line dramatic closer, a triad reached for by rule, arguing
with an unraised objection) and links to an external humanizer reference
for a deeper catalog. `AGENTS.md` elevated `writing-style.md` to a
numbered core principle, since its scope is genuinely universal rather
than tied to one task type, and added explicit pointers to it from
`core/bug-fix.md` and `core/feature-development.md`'s own Report steps.

## 1.13.1 — 2026-09-11
End-to-end testing of 1.13.0's fixes — real git commits through the
actual pre-commit hook, not just unit-testing the script in isolation —
caught one real regression that 1.13.0 itself had introduced:
`scripts/detect-secrets.sh`'s new connection-string pattern matched its
own descriptive comment, so committing the script (or
`safety/secret-scan.md`, which described the same pattern the same way)
blocked on itself. Fixed by rewording both to describe the shape rather
than give a literal matching example. Verified in a scratch repo with
the real pre-commit hook: the script and doc file now pass their own
scan, real secrets are still rejected, and ordinary commits are
unaffected.

## 1.13.0 — 2026-09-11
A self-audit pass: applied `core/engineering-loop.md`'s own
reproduce-confirm-verify discipline to the playbook set itself. Five
parallel reviews across different folders surfaced roughly 30 real
gaps, each independently re-confirmed before being fixed. Highlights:
fixed 8 stale links in `AGENTS.md` left over from the 1.12.0 reorg and
canonicalized its destructive-action wording, which had drifted into
three different versions across files; closed several more
`scripts/block-dangerous.sh` bypasses (force-push with a remote/branch
named, split/extra flags, lowercase `drop table`, raw disk-device
overwrites) and added a `scripts/detect-secrets.sh` pattern for a
generic embedded-credential connection string; stopped
`quality/docs-sync.md` from auto-classifying a security- or
data-integrity-relevant disagreement as harmless "drift"; and made
independent verification an explicit, disclosed step in
`core/bug-fix.md`, `core/feature-development.md`, and
`quality/code-review.md` rather than letting the implementer's own
re-run stand in for it. A long tail of smaller fixes touched incident
response, security review, and most of the remaining playbook folders.
Verified: both script fixes were tested against the exact bypass
commands found (all now blocked) plus a false-positive control set (all
still pass), and the repo-wide cross-reference resolver came back clean
across 41 files.

## 1.12.0 — 2026-09-09
Internal reorganization only, with no user-facing behavior change: moved
8 playbooks that sat loose at the repo root into three new category
folders — `project/` (`project-bootstrap.md`, `project-audit.md`),
`mapping/` (`codebase-mapping.md`, `database-mapping.md`,
`third-party-api-integration.md`), and `media/` (`demo-video.md`,
`video-review.md`, `doc-review.md`) — matching the folder-by-concern
structure the README already described. Every cross-reference to and
from these files was updated and checked with a script that resolves
every `*.md` reference against the real filesystem, which also caught
and fixed two unrelated pre-existing broken links and a missing README
listing for `project-audit.md`. Verified: the resolver ran clean (0
broken references) after all fixes.

## 1.11.0 — 2026-09-09
Added matching guidance to `quality/frontend-testing.md` (step 14) and
`quality/backend-testing.md` (step 8): locators (frontend) or query/
mutation definitions (backend) should live in exactly one place across a
whole suite — either as page-object properties or a separate locator/
query module — with no mixing of conventions or inline one-off locators.
Also required routing logging through one small shared logger reserved
for a genuine "a human may need to act on this" moment, not routine
narration. Verified by auditing a real frontend/backend test-suite pair:
both already followed the locator convention, and a shared logger was
added and exercised for real, including flagging a genuinely orphaned
record left by a test with no cleanup API. The audit also turned up two
unrelated real bugs along the way — a previously-passing soft-delete
assertion that was actually wrong, and a create-record endpoint 500ing
on valid input — both now tracked as known, reproducing bugs rather than
left silently broken.

## 1.10.0 — 2026-09-09
Added three boundary-condition categories to `quality/backend-testing.md`
step 3, found by asking what was still missing after the 1.9.0 pass
rather than assuming it was complete: cross-tenant data isolation as its
own condition distinct from authentication (a valid token can still
reach another tenant's data), rate limiting (a shrinking-quota header
isn't proof the limit is enforced — only exhausting it proves anything),
and pagination boundary values plus stability under a changing data set.
Partially verified: the rate-limiting category is grounded in real
evidence already captured during the 1.9.0 pass (real rate-limit headers
on a client's API); tenant isolation and pagination-boundary testing
hadn't yet been run for real against that project's own backend test
repo.

## 1.9.0 — 2026-09-09
Extended `quality/backend-testing.md` with the same manual-pass →
evidence-backed report → codify-into-test-code shape `frontend-testing.md`
got in 1.8.0, plus explicit REST/OpenAPI-vs-GraphQL guidance it didn't
have before — naming each as distinct paradigms with different sources
of truth and failure shapes, notably that a GraphQL response can be
`200 OK` with the real error sitting in the response body. New steps 7-8
add the manual/exploratory pass this file previously lacked: hit the
real endpoint, capture actual request/response evidence, then codify it
into test code under the same senior-engineer bar as the frontend side.
Verified end to end against a real client's live GraphQL backend —
introspected the real schema, built and ran a 23-test suite, and caught
real findings (auth failures returning HTTP 200, two genuinely different
absent-data shapes for validation-vs-execution failures, a real
inconsistency between two entities' soft-delete behavior) plus one real
mistake (a guessed filter argument name) caught by actually running it.
The REST-vs-GraphQL distinction was separately confirmed against a real
REST multipart-upload endpoint on the same backend, which also surfaced
and fixed a real test-config bug forcing the wrong content type onto
that endpoint.

## 1.8.0 — 2026-09-08
Extended `quality/frontend-testing.md`'s manual/exploratory-pass step
with three new steps and a concrete code-quality bar, verified end to
end against a real client app (a fleet-management CMS) and its staging
environment. The manual pass now also captures network/API evidence
alongside screenshots; a new report step turns a manual pass into an
evidence-backed writeup matching the shape `video-review.md`/
`doc-review.md` already use; and a new codification step turns that pass
into real automated test code — grounded in the actual source, designed
to create and clean up its own data, held to a senior-engineer
code-quality bar, and explicit about where new test code should live
rather than defaulting into the target app's own repo. Also added named
edge-case categories (boundary values, error states, unusual sequences,
permission boundaries), concrete responsive breakpoints, explicit
handling for animated/transitioning elements and CSS-effect-driven
components, and recognition of six non-CRUD flow shapes (wizards,
dashboards, search/filter, upload/download, real-time, background jobs).
Verified for real: ran the updated process against the client's staging
CMS, found and documented five real bugs, then built and ran a 20-test
Playwright suite in a new dedicated repo — catching and fixing two more
real bugs in the test code itself along the way.

## 1.7.0 — 2026-09-08
Extended `quality/frontend-testing.md` and `quality/backend-testing.md`
with tech/platform-agnostic testing discipline drawn from a real QA
report review earlier in this project (via `doc-review.md` against a
real mobile app and its real Katalon test suite), generalized beyond
that specific framework. `frontend-testing.md`: wait for the real
interactable state (not just presence), prefer stable purpose-built
locators over positional ones on web or native mobile, don't assume
screen/list state survives an action unchanged, and one-action-per-step
discipline to catch duplicated steps — also fixed a pre-existing stale
step-number cross-reference in the file's own "Who uses this" section.
`backend-testing.md`: test the second call of an idempotent operation
explicitly (not just the first), wait on the real async completion
condition instead of a fixed sleep, and treat "passes standalone, fails
in the full suite" as the concrete symptom of test-order/state
dependency.

## 1.6.3 — 2026-09-08
Fixed `scripts/record-screen.sh` (`demo-video.md`'s screen-recording
step): `-pix_fmt yuv420p` placed before the output path is read by
avfoundation's demuxer as an *input* capture-format request on some
hardware, and can fail outright there since avfoundation only offers a
handful of raw formats — found on real hardware by actually running it
and getting a silently-empty output file, not assumed from the docs.
Moved it to an explicit output-side `-vf format=yuv420p` filter instead,
which can't be misread as an input request, in both the `start` and
`timed` code paths. Verified: run for real on macOS, producing a valid
recording with real, non-blank screen content — though the specific
failure this fixes is hardware/ffmpeg-build-dependent and did not
reproduce on the machine used to verify it here.

## 1.6.2 — 2026-09-08
Sharpened `doc-review.md`'s page-image guidance from real production use,
not synthetic testing: reviewing a real 146-page third-party QA report
against a real codebase surfaced two real gaps in the previous guidance.
First, the `sparse` page-image heuristic (average non-space characters
per page) can't catch a screenshot with no adjacent caption text —
common in QA reports where some screenshots are auto-captured rather
than produced by a scripted step. Fixed the guidance, not the scripts
(both were already correct): once investigating one specific finding in
depth, render every page across its full range explicitly rather than
trusting the heuristic alone. Second, found immediately after on the
same document: a test case reported overall status "ERROR" while every
one of its visible steps read "PASSED," with no reason given in the
text. Following the new guidance above surfaced the real cause in two
uncaptioned screenshots (a voucher redeemed, then the same voucher
redeemed again and correctly refused by the app). Added a specific
trigger: a section's overall status not matching what its visible steps
show is itself the signal to render that section's full page range, not
a dead end.

## 1.6.0 — 2026-09-08
Added `doc-review.md` + `scripts/extract-doc-text.sh`,
`scripts/render-doc-pages.sh`, `scripts/doc-page-index.sh` — the same
pipeline as `video-review.md` applied to a document instead of a
recording: extract text (`pdftotext` for PDF, `pandoc` for DOCX/ODT/RTF/
HTML/etc.), optionally render scanned/visual pages as images, draft
findings (summary/key points/queries raised/action items split fix-vs-
build), re-verify each one against the actual text/page evidence, then
optionally route each action item to `core/engineering-loop.md` one at a
time. Also added token-bounded processing for large inputs, on both
playbooks: `extract-media.sh`'s frame interval now defaults to `auto`
(duration ÷ 120 frames, floored at 3s) instead of a fixed 5s, so a 4-hour
recording and a 12-second one both land around ~120 frames; and
`doc-page-index.sh` gives line-number-per-page boundaries so a
several-hundred-page document can be read in ~20-page chunks instead of
loading it whole.

Tested directly on macOS, including against a real 146-page, 10MB
third-party PDF (a Katalon mobile-app test report, not synthetic) —
extracted cleanly, chunked-read for real (not just designed), and cross-
checked page-to-line mapping directly against the file's real content.
Two real bugs were found and fixed during this pass: a page-count
off-by-one in the sparse-page-warning math, and `render-doc-pages.sh`
producing double-suffixed filenames because `pdftoppm` appends its own
page number even for a single-page render (fixed with `-singlefile`). A
full run through `core/engineering-loop.md` was also done, real not
simulated — the same throwaway-repo bug-fix scenario from
`video-review.md`'s own verification, this time driven by a synthetic
PDF. `extract-media.sh`'s new `auto` interval was verified against a
genuinely 4-hour-long synthetic video: correctly computed a 120s interval
and extracted exactly 120 frames. Not run on Linux/Windows directly (no
such environment available); same plain POSIX-bash + real-CLI-tool shape
already exercised cross-platform-honestly elsewhere in this repo.

A further re-verification pass found two more real bugs, fixed before
release. `extract-media.sh`: `frame_last.png` could silently fail to be
written at all while the script still reported success (`ffmpeg` seeking
too close to EOF can produce zero output while still exiting 0) — fixed
with a bounded retry at increasing margins plus an explicit
file-existence check instead of trusting the exit code.
`extract-doc-text.sh`: the file extension was detected from the full path
instead of the filename, so a dotted parent directory (e.g. a `v2.0/`
folder) corrupted detection for an extensionless file inside it — fixed
by extracting from `basename` instead. Both re-confirmed against the
exact cases that exposed them.

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
also caught and fixed two real bugs before any of this shipped:
`extract-media.sh` didn't clear `frames/` before re-extracting, so a
re-run with a different interval (or a swapped-in audio-only input) left
stale frames from the previous run mixed in silently; `transcribe.sh`'s
`whisper` (openai-whisper) branch swallowed both stdout and stderr, so a
real failure there (bad audio, a failed model download) would have died
with zero explanation, contradicting this repo's own no-silent-failure
convention. Both are fixed and re-tested (including a forced-failure case
proving the error now surfaces, and a stand-in success case proving the
output-file move logic still matches the real CLI's documented naming).

The real `openai-whisper` transcription output has since been confirmed
too. The first pip install attempt failed building `llvmlite` from source
(no wheel for the version pip picked); forcing wheel-only resolution
(`pip install --only-binary=llvmlite,numba -U openai-whisper`) got past
it, and a follow-on NumPy 1.x/2.x ABI crash on first run was fixed with
`pip install 'numpy<2'` — both now documented as Prerequisites in
`video-review.md`. With a working install, `transcribe.sh` was run
unmodified against real spoken narration (macOS `say`, not a synthetic
tone) both directly and through the full `extract-media.sh` →
`transcribe.sh` chain, with both the `tiny` and default `base` models, and
produced an accurate transcript each time. `whisper.cpp` remains
genuinely unverified (no local build available) — same caveat this repo
already gives Piper in `demo-video.md`. Not run on Linux/Windows directly
(no such environment available); same ffmpeg-only POSIX-bash design as
the already-multi-OS `demo-video.md` scripts.

A second re-verification pass found one more real bug: `extract-media.sh`
extracted audio unconditionally, so a video with no audio stream at all
(mic off, a muted screen capture — a realistic input, not a corrupt one)
made the whole script die on that step with a cryptic ffmpeg error, never
reaching frame extraction. Fixed the same way as the earlier audio-only
case (check for the stream first, skip and say so if it's missing, keep
going) and re-tested against a real silent clip alongside the existing
normal/audio-only/missing-file cases to confirm no regression.

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
