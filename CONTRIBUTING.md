# Contributing

## What lives in this repo

Just the installer, docs, and the distribution backend's public-facing
half (`install.sh`, `README.md`, `CHANGELOG.md`, `supabase/`, `tests/`,
this CI). The playbook content itself (`agent-playbooks/`, `AGENTS.md`)
isn't source here — `install.sh` fetches it from a release at install
time (see [README.md](README.md#how-this-is-distributed)). So:

- **Bug reports / fixes / improvements for the installer, docs, backend,
  or tests** — welcome here, normal PR flow below.
- **Playbook content itself** (wording, a new playbook, a fix to one
  file's process) — not something this repo's PRs can carry, since the
  content is licensed and distributed separately. Open an issue
  describing what's wrong or missing and it'll get picked up on the
  content side; a released fix shows up as a normal version bump you can
  install like any other.

## Before opening a PR

1. **Shellcheck** everything that changed:
   ```bash
   shellcheck install.sh tests/*.sh tests/support/*.sh 2>/dev/null
   ```
   (or let CI run it — same check, `.github/workflows/ci.yml`).

2. **Run the install smoke test** if you touched `install.sh`, the
   backend response shape, or anything under `tests/`:
   ```bash
   ./tests/install-smoke-test.sh
   ```
   This runs `install.sh` against a local mock server with a throwaway
   signing key (never the real one — that only ever exists on the
   maintainer's machine) and checks: a clean install lands the right
   files, tampered content is rejected, a legitimately watermarked
   `AGENTS.md` still installs, a missing manifest is refused, and a
   release signed with the wrong key is refused. Add a case here for any
   new failure mode you're fixing — a fix without a test that would have
   caught the original bug is easy to silently regress later.

3. If you changed `supabase/functions/check-in/index.ts`, type-check it:
   ```bash
   deno check supabase/functions/check-in/index.ts
   ```

## Why you can't fully test signature verification locally with the real key

`install.sh`'s `ALLOWED_SIGNERS` is the maintainer's real public key,
hardcoded. There's no way to sign a fixture that verifies against it
without the private half, which is intentionally never in this repo, CI,
or anywhere but the maintainer's machine. The smoke test works around
this with `AGENT_PLAYBOOKS_ALLOWED_SIGNERS`, an env var `install.sh`
checks *only* to let tests substitute a throwaway key — it has no effect
on a real install, and PRs that touch this mechanism should assume an
attacker could set it too, so any change here needs to hold up under
"the attacker controls every env var" as the threat model, not just the
happy path.

## Style

Match what's already there: this codebase explains *why*, not *what*, in
comments — especially for anything non-obvious that was found by actually
testing it (a portability gap, a bash version quirk, a real bypass), not
assumed. See the existing comments in `install.sh` for the tone.
