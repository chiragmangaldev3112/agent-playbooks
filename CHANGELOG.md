# Changelog

Every entry here corresponds to a real, tested change to the playbook
content — not a version bump for its own sake. See `agent-playbooks/VERSION`
for the currently-installed version; a fresh `install.sh` run always fetches
the latest, and now prints the version it installed.

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
