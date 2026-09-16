# Security

## Reporting a vulnerability

Preferred: open a [private security advisory](https://github.com/chiragmangaldev3112/agent-playbooks/security/advisories/new)
on this repo. If that's not workable, email chiragmangal3112@gmail.com with
`agent-playbooks security` in the subject.

Please don't open a public issue for anything that isn't already public
knowledge. Include enough to reproduce it — for `install.sh`, that usually
means the exact command and environment (OS, shell, tool versions); for the
backend, the request/response you saw (redact your own install ID if you'd
rather not share it).

## What's in scope

- `install.sh` — the installer, including release-integrity verification.
- `supabase/schema.sql` / `supabase/functions/check-in/index.ts` — the
  distribution backend. Both are fully readable in this repo; nothing about
  the mechanism is hidden.
- `.github/workflows/` and the test scripts under `tests/`.

The playbook content itself (`agent-playbooks/`, fetched on install) isn't
source in this repo — see [README.md](README.md#how-this-is-distributed).
A vulnerability in what a playbook tells an agent to do is still in scope
here; report it the same way.

## The actual trust model

Worth reading before assuming a guarantee this doesn't make:

- **Release integrity**: every release is signed with an Ed25519 key that
  never leaves the maintainer's machine (see
  [README.md#verifying-a-release](README.md#verifying-a-release)).
  `install.sh` verifies the signature and re-hashes every file before
  writing anything. This means a compromised or spoofed check-in backend
  can't silently substitute different content — but it *can* still
  withhold a release, log check-ins, or serve a `blocked` response. That's
  a deliberate, disclosed limit of the design, not a gap in it.
- **The safety guardrail** (`agent-playbooks/safety/safety-guardrail.md`,
  `scripts/block-dangerous.sh`) is a deterministic deny-list against a
  fixed set of destructive shell command patterns, wired in as a real
  pre-execution hook where the host tool supports it (e.g. Claude Code's
  `PreToolUse`). It is explicitly **not** a complete security boundary —
  its own doc lists what it doesn't catch (merge/push/deploy commands,
  a dangerous action hidden inside a script the agent wrote and then ran,
  anything not literally in the deny list). Treat "not on the list" as a
  real gap, not an oversight to assume is covered.
- **No content mutation at all**: the check-in endpoint is a pure
  passthrough — it does not modify any file before returning it. An
  earlier version injected a per-install tracking watermark into
  `AGENTS.md`; that was removed once the content was relicensed MIT (see
  `agent-playbooks/CHANGELOG.md` 1.19.0), since tracing an "unauthorized"
  copy stopped being meaningful once redistribution became explicitly
  licensed. `AGENTS.md` does carry one permanent, identical-for-everyone
  attribution line baked into its own source — not per-install, not
  hidden, not a tracking mechanism.
- **No credential handling**: the installer and generated artifacts never
  ask for, store, or transmit any third-party API key or credential. The
  backend's own service-role key lives only in the Edge Function's
  server-side environment, never returned to any client.

If you find a way to defeat any of the above (bypass the signature check,
find a guardrail bypass not already documented as a known gap, extract a
credential that shouldn't be reachable, etc.), that's exactly what this
policy wants reported.
