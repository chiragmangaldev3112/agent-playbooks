#!/usr/bin/env bash
# Installs AGENTS.md + agent-playbooks/ into a target project, plus a
# minimal CLAUDE.md (only if one doesn't already exist) so Claude Code
# actually picks this up. If run at a real terminal, also asks which AI
# tool you're using and generates real native artifacts for it (Claude
# Code Skills/sub-agents, Cursor rules, or Antigravity Skills) as thin
# pointers back to agent-playbooks/ -- Codex CLI and Cursor read AGENTS.md
# natively already (confirmed against each tool's own docs) so nothing
# extra is required for them; Antigravity's "reads AGENTS.md
# automatically" is NOT officially documented anywhere, so it gets real
# generated Skills instead of relying on that. Zero setup: no account, no
# token, nothing to ask the maintainer for -- just run it. This repo does
# not carry the playbook content itself; it fetches the current release
# from a check-in endpoint on each install (see README.md for exactly
# what that does and doesn't do -- including a per-install watermark
# woven into AGENTS.md's own content, invisible in normal rendering).
# Requires curl, jq, base64 (standard on macOS/Linux) and a shell that
# can run bash. macOS and Linux have this natively; Windows does not --
# run this via WSL or Git Bash, not from a plain Command
# Prompt/PowerShell session (same constraint as this repo's other bash
# scripts, e.g. media/demo-video.md's).
#
# Usage:
#   ./install.sh                       # installs into the current directory
#   ./install.sh /path/to/repo         # installs into that directory instead
#   ./install.sh --version 1.0.5       # pins to that release instead of latest
#   ./install.sh --version=1.0.5 /path # flag and target dir together, any order
#   ./install.sh --only bug-fix        # just that playbook (+ what it needs)
#   ./install.sh --only bug-fix,code-review,core/engineering-loop.md
#
# Set AGENT_PLAYBOOKS_TOOL=claude|cursor|antigravity|codex|copilot|none to
# skip the interactive tool prompt (e.g. for a non-interactive/CI install).
#
# Set AGENT_PLAYBOOKS_VERSION=1.0.5 (or --version 1.0.5) to install a
# specific past release instead of whatever's currently latest. See
# CHANGELOG.md in this repo for the list of released versions and what
# changed in each. Omit this and you get latest, same as always.
#
# Set AGENT_PLAYBOOKS_ONLY=bug-fix,code-review (or --only bug-fix,code-review)
# to install just those playbook(s) instead of the full set -- a bare name
# (with or without .md) is resolved by searching agent-playbooks/ for a
# matching filename, or give a path relative to agent-playbooks/ directly
# (core/bug-fix.md) if two playbooks happen to share a basename. This still
# fetches the whole release from the server (there's no partial-fetch API),
# but only writes the requested file(s) to disk -- PLUS, recursively,
# anything any of them actually references (a backtick-quoted, slash-
# containing path to another .md or .sh file, the same convention checked
# against this repo's real cross-references before this feature was built).
# AGENTS.md/VERSION/LICENSE are always included regardless, since every
# install needs an entry point and the license that governs the content.
# The tool-artifact generators below (Claude Skills, Cursor rules, etc.)
# already scan whatever's actually on disk, so a reduced install
# automatically gets a reduced, still-correct set of generated artifacts.
#
# Claude Code only: each generated sub-agent (.claude/agents/*.md) is
# tagged in autonomy/roles.md as "verify" (Code Reviewer, Manual/
# Exploratory Tester, and Bug Hunter -- Bug Hunter also fixes, but
# engineering-loop.md names it as the independent-verification pass for a
# bug fix, so it takes the stricter tier -- catches what someone else got
# wrong, so it defaults to the strongest model) or "implement" (Feature
# Builder, Test Writer, Project Bootstrapper -- does work a verify pass
# independently re-checks, so a lighter/faster model is fine). Override
# per persona with AGENT_PLAYBOOKS_MODEL_<PERSONA_NAME> (e.g.
# AGENT_PLAYBOOKS_MODEL_CODE_REVIEWER=haiku), or per tier with
# AGENT_PLAYBOOKS_MODEL_VERIFY / AGENT_PLAYBOOKS_MODEL_IMPLEMENT (set both
# to the same value for "one model for every persona"). Checked most-
# specific first; unset means the opus/sonnet default.
#
# After this finishes, point your AI coding agent at
# agent-playbooks/project/project-bootstrap.md in the target project -- the smart,
# context-aware pass that grounds AGENTS.md in the target's real stack and
# wires the safety guardrail + personas into whichever tool you use there.

set -euo pipefail

requested_version="${AGENT_PLAYBOOKS_VERSION:-}"
only_requested="${AGENT_PLAYBOOKS_ONLY:-}"
positional=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) requested_version="${2:?--version needs a value, e.g. --version 1.0.5}"; shift 2 ;;
    --version=*) requested_version="${1#--version=}"; shift ;;
    --only) only_requested="${2:?--only needs a value, e.g. --only bug-fix}"; shift 2 ;;
    --only=*) only_requested="${1#--only=}"; shift ;;
    *) positional+=("$1"); shift ;;
  esac
done
set -- "${positional[@]:-}"

TARGET_DIR="${1:-.}"
CHECK_IN_URL="${AGENT_PLAYBOOKS_CHECK_IN_URL:-https://cjogceoqhgjzpalbqpga.supabase.co/functions/v1/check-in}"
ID_FILE="${AGENT_PLAYBOOKS_ID_FILE:-$HOME/.agent-playbooks-id}"

for cmd in curl jq base64; do
  command -v "$cmd" >/dev/null || { echo "Error: '$cmd' is required and was not found." >&2; exit 1; }
done

mkdir -p "$TARGET_DIR"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

if [[ -e "$TARGET_DIR/AGENTS.md" ]]; then
  echo "AGENTS.md already exists at $TARGET_DIR/AGENTS.md -- not overwriting it." >&2
  echo "Merge by hand, or remove it first if you want a clean copy." >&2
  exit 1
fi
if [[ -e "$TARGET_DIR/agent-playbooks" ]]; then
  echo "$TARGET_DIR/agent-playbooks already exists -- not overwriting it." >&2
  echo "Remove or rename it first if you want a clean copy." >&2
  exit 1
fi

if [[ ! -f "$ID_FILE" ]]; then
  if command -v uuidgen >/dev/null; then
    uuidgen > "$ID_FILE"
  else
    { date +%s%N; echo "$RANDOM"; } | shasum | cut -c1-32 > "$ID_FILE"
  fi
fi
local_id="$(cat "$ID_FILE")"

echo "Fetching the current release..."
payload="$(jq -n --arg id "$local_id" --arg rv "$requested_version" \
  'if $rv == "" then {p_id: $id} else {p_id: $id, p_requested_version: $rv} end')"
response="$(curl -fsSL --max-time 15 -X POST \
  "$CHECK_IN_URL" \
  -H "Content-Type: application/json" \
  -d "$payload")" || {
  echo "Error: could not reach the check-in endpoint. Check your network." >&2
  exit 1
}

echo "$response" | jq -e . >/dev/null 2>&1 || {
  echo "Error: backend returned something unreadable:" >&2
  echo "$response" >&2
  exit 1
}

is_blocked="$(echo "$response" | jq -r '.[0].blocked // false')"
if [[ "$is_blocked" == "true" ]]; then
  message="$(echo "$response" | jq -r '.[0].blocked_message // "Access denied."')"
  echo "BLOCKED: $message" >&2
  exit 1
fi

archive_json="$(echo "$response" | jq -r '.[0].archive_base64 // empty')"
if [[ -z "$archive_json" ]]; then
  echo "Error: no release archive returned. No published release yet?" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# The release is a JSON object mapping each relative file path to its
# base64 content (not a tar.gz) -- reconstruct the real file tree from it.
echo "$archive_json" | jq -e . >/dev/null 2>&1 || {
  echo "Error: fetched release archive isn't valid JSON." >&2
  exit 1
}
while IFS=$'\t' read -r relpath content_b64; do
  [[ -z "$relpath" ]] && continue
  outpath="$WORKDIR/$relpath"
  mkdir -p "$(dirname "$outpath")"
  printf '%s' "$content_b64" | base64 -d > "$outpath" || {
    echo "Error: could not decode file '$relpath' from the fetched release." >&2
    exit 1
  }
done < <(echo "$archive_json" | jq -r 'to_entries[] | "\(.key)\t\(.value)"')

installed_version="$(cat "$WORKDIR/agent-playbooks/VERSION" 2>/dev/null | tr -d '[:space:]')"
[[ -z "$installed_version" ]] && installed_version="unknown"

if [[ ! -f "$WORKDIR/AGENTS.md" || ! -d "$WORKDIR/agent-playbooks" ]]; then
  echo "Error: fetched release doesn't contain AGENTS.md / agent-playbooks/." >&2
  exit 1
fi

cp "$WORKDIR/AGENTS.md" "$TARGET_DIR/AGENTS.md"
mkdir -p "$TARGET_DIR/agent-playbooks"

if [[ -z "$only_requested" ]]; then
  cp -R "$WORKDIR/agent-playbooks/." "$TARGET_DIR/agent-playbooks/"
else
  # --only mode: resolve each requested name to a real file under
  # agent-playbooks/, then bring along what it actually needs to work --
  # bounded two ways, both found by testing this against the real repo
  # before settling on the design:
  #   1. Following .md references fully transitively explodes to nearly
  #      the whole repo the moment core/engineering-loop.md is reached (it's
  #      the router -- referencing almost every other playbook by design,
  #      not a real dependency chain). So a requested playbook's own DIRECT
  #      .md references are included, but references-of-references are not
  #      followed further -- a "see also" pointer two hops away isn't a
  #      real requirement to install.
  #   2. A .sh script reference is a genuine functional need (a playbook
  #      that says "run ../scripts/x.sh" doesn't work without it), so those
  #      ARE followed fully transitively, from the requested file(s) and
  #      from whatever direct .md dependency got pulled in above.
  # Canonicalized (symlinks resolved) up front, not left as whatever form
  # $WORKDIR happened to be in -- macOS's mktemp -d returns a path under
  # /var/folders/..., but /var is itself a symlink to /private/var, so a
  # later `cd ... && pwd -P` (used to resolve a "../x" reference) returns
  # the /private/var/... form. Comparing one against the other silently
  # failed every "is this still inside pb_root" check below; confirmed by
  # tracing the actual mismatch on a real Mac before this fix.
  pb_root="$(cd "$WORKDIR/agent-playbooks" && pwd -P)"
  # Plain indexed array + linear-search dedup, not an associative array --
  # macOS ships bash 3.2 by default (associative arrays need bash 4+), and
  # this script explicitly targets "macOS and Linux natively," confirmed by
  # actually invoking /bin/bash on a real Mac before settling on this,
  # not assumed portable from reading bash's changelog.
  included=()
  contains() {
    local needle="$1" x
    # Guard against expanding an empty array under `set -u` -- bash < 4.4
    # (macOS's default /bin/bash is 3.2) treats "${arr[@]}" on a truly
    # empty array as an unbound variable, not an empty expansion. Confirmed
    # by actually hitting this exact error on a real Mac before the guard.
    [[ ${#included[@]} -eq 0 ]] && return 1
    for x in "${included[@]}"; do
      [[ "$x" == "$needle" ]] && return 0
    done
    return 1
  }
  # Resolves a reference string (e.g. "../quality/writing-style.md") found
  # inside $1 (a path relative to pb_root) to a path relative to pb_root,
  # or prints nothing if it doesn't resolve to a real file inside the tree.
  resolve_ref() {
    local from_relpath="$1" ref="$2" from_dir ref_dir ref_base resolved_dir resolved_abs
    from_dir="$(dirname "$pb_root/$from_relpath")"
    ref_dir="$(dirname "$ref")"
    ref_base="$(basename "$ref")"
    resolved_dir="$(cd "$from_dir" 2>/dev/null && cd "$ref_dir" 2>/dev/null && pwd -P)" || return 0
    resolved_abs="$resolved_dir/$ref_base"
    [[ "$resolved_abs" != "$pb_root/"* ]] && return 0
    [[ -f "$resolved_abs" ]] || return 0
    echo "${resolved_abs#"$pb_root"/}"
  }
  queue=()

  IFS=',' read -r -a requested_names <<< "$only_requested"
  for raw_name in "${requested_names[@]}"; do
    name="$(echo "$raw_name" | xargs)"
    [[ -z "$name" ]] && continue
    if [[ "$name" == */* ]]; then
      candidate="$name"
      [[ "$candidate" != *.md ]] && candidate="${candidate}.md"
      if [[ ! -f "$pb_root/$candidate" ]]; then
        echo "Error: --only requested '$name' -- no file at agent-playbooks/$candidate" >&2
        exit 1
      fi
      queue+=("$candidate")
    else
      base="${name%.md}.md"
      matches=()
      while IFS= read -r -d '' f; do
        matches+=("${f#"$pb_root"/}")
      done < <(find "$pb_root" -name "$base" -print0)
      if [[ ${#matches[@]} -eq 0 ]]; then
        echo "Error: --only requested '$name' -- no playbook matching '$base' found under agent-playbooks/" >&2
        exit 1
      elif [[ ${#matches[@]} -gt 1 ]]; then
        echo "Error: --only '$name' matches more than one file, be specific with a path: ${matches[*]}" >&2
        exit 1
      fi
      queue+=("${matches[0]}")
    fi
  done
  directly_requested=("${queue[@]}")
  for relpath in "${directly_requested[@]}"; do
    included+=("$relpath")
  done

  # Phase 1: each directly-requested file's own DIRECT references (.md and
  # .sh both) -- one hop only, no further recursion into what those
  # references themselves mention.
  direct_deps=()
  for seed in "${directly_requested[@]}"; do
    while IFS= read -r ref; do
      [[ -z "$ref" ]] && continue
      resolved="$(resolve_ref "$seed" "$ref")"
      if [[ -n "$resolved" ]] && ! contains "$resolved"; then
        included+=("$resolved")
        direct_deps+=("$resolved")
      fi
    done < <(grep -oE '`[./]*[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)+\.(md|sh)`' "$pb_root/$seed" 2>/dev/null | tr -d '`')
  done

  # Phase 2: from every file gathered so far, follow .sh references only,
  # fully transitively -- a real functional need, not a routing pointer.
  # Built via explicit append, not "arrA[@] arrB[@]" concatenation -- the
  # same empty-array-under-set-u trap applies there too on bash 3.2 when
  # direct_deps has zero elements, confirmed by hitting it for real.
  sh_queue=()
  for x in "${directly_requested[@]}"; do sh_queue+=("$x"); done
  if [[ ${#direct_deps[@]} -gt 0 ]]; then
    for x in "${direct_deps[@]}"; do sh_queue+=("$x"); done
  fi
  idx=0
  while [[ $idx -lt ${#sh_queue[@]} ]]; do
    current="${sh_queue[$idx]}"
    idx=$((idx + 1))
    while IFS= read -r ref; do
      [[ -z "$ref" ]] && continue
      resolved="$(resolve_ref "$current" "$ref")"
      if [[ -n "$resolved" ]] && ! contains "$resolved"; then
        included+=("$resolved")
        sh_queue+=("$resolved")
      fi
    done < <(grep -oE '`[./]*[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)+\.sh`' "$pb_root/$current" 2>/dev/null | tr -d '`')
  done

  for relpath in "${included[@]}"; do
    mkdir -p "$TARGET_DIR/agent-playbooks/$(dirname "$relpath")"
    cp "$pb_root/$relpath" "$TARGET_DIR/agent-playbooks/$relpath"
  done
  cp "$pb_root/VERSION" "$TARGET_DIR/agent-playbooks/VERSION" 2>/dev/null || true
  cp "$pb_root/LICENSE" "$TARGET_DIR/agent-playbooks/LICENSE" 2>/dev/null || true
  chmod +x "$TARGET_DIR"/agent-playbooks/scripts/*.sh 2>/dev/null || true

  echo "--only: requested ${directly_requested[*]}" >&2
  pulled_in=()
  for relpath in "${included[@]}"; do
    is_direct=0
    for d in "${directly_requested[@]}"; do
      [[ "$d" == "$relpath" ]] && is_direct=1 && break
    done
    [[ $is_direct -eq 0 ]] && pulled_in+=("$relpath")
  done
  if [[ ${#pulled_in[@]} -gt 0 ]]; then
    echo "--only: pulled in as real dependencies: ${pulled_in[*]}" >&2
  fi
fi
chmod +x "$TARGET_DIR"/agent-playbooks/scripts/*.sh 2>/dev/null || true

# Codex CLI and Cursor both read AGENTS.md at the project root natively,
# confirmed against each tool's own official docs -- nothing more needed
# for them. Claude Code only auto-loads CLAUDE.md, never AGENTS.md, so a
# one-line CLAUDE.md is created unconditionally (harmless/inert to every
# other tool) rather than gated behind tool detection.
claude_md_status="created"
if [[ -e "$TARGET_DIR/CLAUDE.md" ]]; then
  claude_md_status="skipped (already exists)"
  if ! grep -q '@AGENTS.md' "$TARGET_DIR/CLAUDE.md" 2>/dev/null; then
    echo "Note: $TARGET_DIR/CLAUDE.md already exists and doesn't import" >&2
    echo "AGENTS.md -- if you're using Claude Code, add a line containing" >&2
    echo "'@AGENTS.md' to it yourself so Claude Code actually loads this." >&2
  fi
else
  echo "@AGENTS.md" > "$TARGET_DIR/CLAUDE.md"
fi

# --- Optional deeper per-tool native artifacts -----------------------------
# AGENTS.md + CLAUDE.md above is enough for every tool that reads AGENTS.md
# on its own (Codex CLI, Cursor). Antigravity's "reads AGENTS.md
# automatically" is NOT officially documented anywhere (checked directly
# against its docs) so it gets real generated Skills instead, not an
# assumption. Claude Code and Cursor also get real generated
# Skills/rules for explicit /name or @name invocation, on top of the
# passive AGENTS.md text. Every generated file is a thin pointer back to
# the real playbook in agent-playbooks/ -- never a content copy -- so nothing
# can drift out of sync between the two.

pb_dir="$TARGET_DIR/agent-playbooks"

# Pulls the one-line description for a playbook: its "Trigger:" line where
# one exists, otherwise a short hand-written fallback for the handful of
# files that don't have one (the router, the two autonomy overviews, the
# demo/memory/guardrail utility files).
extract_description() {
  local f="$1" trig base
  # Join the whole Trigger paragraph (it usually wraps across several
  # physical lines in the source), not just its first line, then trim to
  # a sane length -- a description cut off mid-sentence at the source
  # file's line-wrap point reads as broken, not just short.
  trig="$(awk '/^Trigger/{p=1} p{if ($0=="") exit; line=line $0 " "} END{print line}' "$f" 2>/dev/null || true)"
  if [[ -n "$trig" ]]; then
    trig="$(echo "$trig" | sed -E 's/^Trigger( words)?: //')"
    if [[ ${#trig} -gt 220 ]]; then
      trig="${trig:0:217}..."
    fi
    echo "$trig" | sed 's/"/\\"/g'
    return
  fi
  base="$(basename "$f" .md)"
  case "$base" in
    engineering-loop) echo "Start here for any task -- classifies the request and routes it, enforcing independent verification." ;;
    mission-mode) echo "Standing-objective autonomous operation, with an explicit autonomy dial." ;;
    roles) echo "Reusable personas for sub-agent delegation, and when delegating is actually worth it." ;;
    demo-video) echo "Generate a narrated screen-recording demo from a script, free tools only." ;;
    memory-hygiene) echo "Do not trust a recalled fact about code without re-checking it against the current source." ;;
    safety-guardrail) echo "A real, enforced block on destructive shell commands." ;;
    *) sed -n '3p' "$f" 2>/dev/null | cut -c1-200 | sed 's/"/\\"/g' ;;
  esac
}

generate_claude_artifacts() {
  local skills_dir="$TARGET_DIR/.claude/skills" agents_dir="$TARGET_DIR/.claude/agents"
  mkdir -p "$skills_dir" "$agents_dir"
  local count=0 f relpath slug desc
  while IFS= read -r -d '' f; do
    relpath="agent-playbooks/${f#"$pb_dir"/}"
    slug="$(basename "$f" .md | tr '[:upper:]' '[:lower:]')"
    desc="$(extract_description "$f")"
    mkdir -p "$skills_dir/$slug"
    printf -- '---\ndescription: "%s"\n---\n\nFollow `%s` exactly, as written there.\n' \
      "$desc" "$relpath" > "$skills_dir/$slug/SKILL.md"
    count=$((count + 1))
  done < <(find "$pb_dir" -name "*.md" ! -name "README.md" ! -name "EXAMPLES.md" ! -name "CHANGELOG.md" ! -path "*/examples/*" -print0)

  local personas='bug-hunter|verify|Reproduces a reported bug with a real, runnable failing test before proposing any fix.
feature-builder|implement|Implements a feature test-first: failing test from the spec, implement until it passes.
code-reviewer|verify|Reviews a diff for correctness, security, and convention adherence.
test-writer|implement|Adds test coverage for existing, untested code.
manual-exploratory-tester|verify|Explores a running app or change the way a human tester would.
project-bootstrapper|implement|Onboards an agent to an unfamiliar repo, grounding every claim in real files.'
  local n=0 pslug ptier pdesc model env_name
  while IFS='|' read -r pslug ptier pdesc; do
    [[ -z "$pslug" ]] && continue
    # Most-specific override wins: this exact persona, then its tier, then
    # the opus(verify)/sonnet(implement) built-in default. Same override
    # covers "pin one persona," "one model for everything" (set both tier
    # vars the same), and "leave it at the sane default" (set nothing).
    env_name="AGENT_PLAYBOOKS_MODEL_$(echo "$pslug" | tr '[:lower:]-' '[:upper:]_')"
    if [[ -n "${!env_name:-}" ]]; then
      model="${!env_name}"
    elif [[ "$ptier" == "verify" && -n "${AGENT_PLAYBOOKS_MODEL_VERIFY:-}" ]]; then
      model="$AGENT_PLAYBOOKS_MODEL_VERIFY"
    elif [[ "$ptier" == "implement" && -n "${AGENT_PLAYBOOKS_MODEL_IMPLEMENT:-}" ]]; then
      model="$AGENT_PLAYBOOKS_MODEL_IMPLEMENT"
    elif [[ "$ptier" == "verify" ]]; then
      model="opus"
    else
      model="sonnet"
    fi
    printf -- '---\nname: %s\ndescription: "%s"\nmodel: %s\ntools: Read, Grep, Glob, Bash\n---\n\nFollow the persona defined in `agent-playbooks/autonomy/roles.md` exactly (the section matching this agent'"'"'s name).\n' \
      "$pslug" "$pdesc" "$model" > "$agents_dir/$pslug.md"
    n=$((n + 1))
  done <<< "$personas"
  echo "Generated $count Claude Code Skills (.claude/skills/) and $n sub-agents (.claude/agents/, model-tiered per autonomy/roles.md)." >&2
}

generate_cursor_artifacts() {
  local rules_dir="$TARGET_DIR/.cursor/rules"
  mkdir -p "$rules_dir"
  local count=0 f relpath slug desc
  while IFS= read -r -d '' f; do
    relpath="agent-playbooks/${f#"$pb_dir"/}"
    slug="$(basename "$f" .md | tr '[:upper:]' '[:lower:]')"
    desc="$(extract_description "$f")"
    printf -- '---\ndescription: "%s"\nalwaysApply: false\n---\n\nFollow `%s` exactly, as written there.\n' \
      "$desc" "$relpath" > "$rules_dir/$slug.mdc"
    count=$((count + 1))
  done < <(find "$pb_dir" -name "*.md" ! -name "README.md" ! -name "EXAMPLES.md" ! -name "CHANGELOG.md" ! -path "*/examples/*" -print0)
  echo "Generated $count Cursor rules (.cursor/rules/*.mdc, Agent Requested mode --" >&2
  echo "Cursor semantically matches on 'description' the same way Claude Skills do)." >&2
  echo "AGENTS.md is also read natively by Cursor on its own, confirmed in its docs." >&2
}

generate_antigravity_artifacts() {
  local skills_dir="$TARGET_DIR/.agents/skills"
  mkdir -p "$skills_dir"
  local count=0 f relpath slug desc
  while IFS= read -r -d '' f; do
    relpath="agent-playbooks/${f#"$pb_dir"/}"
    slug="$(basename "$f" .md | tr '[:upper:]' '[:lower:]')"
    desc="$(extract_description "$f")"
    mkdir -p "$skills_dir/$slug"
    printf -- '---\ndescription: "%s"\n---\n\nFollow `%s` exactly, as written there.\n' \
      "$desc" "$relpath" > "$skills_dir/$slug/SKILL.md"
    count=$((count + 1))
  done < <(find "$pb_dir" -name "*.md" ! -name "README.md" ! -name "EXAMPLES.md" ! -name "CHANGELOG.md" ! -path "*/examples/*" -print0)
  echo "Generated $count Antigravity Skills (.agents/skills/*/SKILL.md)." >&2
  echo "Unlike Cursor/Codex CLI, Antigravity's own docs never confirm it reads" >&2
  echo "AGENTS.md automatically -- these generated Skills are the reliable path." >&2
}

generate_copilot_artifacts() {
  local out="$TARGET_DIR/.github/copilot-instructions.md"
  mkdir -p "$TARGET_DIR/.github"
  if [[ -e "$out" ]]; then
    echo "Skipped: $out already exists -- not overwriting it." >&2
    return
  fi
  cat > "$out" <<'EOF'
This project uses Agent Playbooks for engineering process. Before any
non-trivial task (bug fix, feature, review, release, etc.), read
`AGENTS.md` at the project root, then follow
`agent-playbooks/core/engineering-loop.md` -- it classifies the request
and routes it to the matching playbook under `agent-playbooks/`.
EOF
  echo "Generated $out (Copilot has no semantic per-file matching the way" >&2
  echo "Claude/Cursor do, so this is one blanket pointer file rather than a" >&2
  echo "separate .instructions.md per playbook)." >&2
}

tool_choice="${AGENT_PLAYBOOKS_TOOL:-}"
if [[ -z "$tool_choice" && -t 0 ]]; then
  echo "" >&2
  echo "Which AI coding tool are you using in this project? (optional -- generates" >&2
  echo "real native Skills/rules for it; Enter/skip leaves just AGENTS.md + CLAUDE.md)" >&2
  echo "  1) Claude Code" >&2
  echo "  2) Cursor" >&2
  echo "  3) Antigravity" >&2
  echo "  4) Codex CLI (reads AGENTS.md natively already -- nothing to generate)" >&2
  echo "  5) GitHub Copilot" >&2
  echo "  6) Other / skip" >&2
  read -r -p "Enter 1-6 [6]: " tool_num || tool_num=""
  case "$tool_num" in
    1) tool_choice="claude" ;;
    2) tool_choice="cursor" ;;
    3) tool_choice="antigravity" ;;
    4) tool_choice="codex" ;;
    5) tool_choice="copilot" ;;
    *) tool_choice="none" ;;
  esac
fi
tool_choice="${tool_choice:-none}"

case "$tool_choice" in
  claude) generate_claude_artifacts ;;
  cursor) generate_cursor_artifacts ;;
  antigravity) generate_antigravity_artifacts ;;
  copilot) generate_copilot_artifacts ;;
  codex|none|*) : ;;
esac

notice="$(echo "$response" | jq -r '.[0].notice // empty')"
[[ -n "$notice" ]] && echo "Notice: $notice"

echo "Installed agent-playbooks v$installed_version:"
echo "  $TARGET_DIR/AGENTS.md"
echo "  $TARGET_DIR/agent-playbooks/"
echo "  $TARGET_DIR/CLAUDE.md ($claude_md_status -- Claude Code only; every"
echo "  other supported tool reads AGENTS.md directly and needs no extra file)"
case "$tool_choice" in
  claude) echo "  $TARGET_DIR/.claude/skills/ and .claude/agents/ (generated)" ;;
  cursor) echo "  $TARGET_DIR/.cursor/rules/ (generated)" ;;
  antigravity) echo "  $TARGET_DIR/.agents/skills/ (generated)" ;;
  copilot) echo "  $TARGET_DIR/.github/copilot-instructions.md (generated, unless it already existed)" ;;
  codex) echo "  (nothing extra -- Codex CLI reads AGENTS.md natively)" ;;
  none) : ;;
esac
echo
echo "Next step: open your AI coding tool in that project and ask it to"
echo "follow agent-playbooks/project/project-bootstrap.md. That pass grounds"
echo "AGENTS.md in the real stack it finds there, and wires the safety"
echo "guardrail + roles.md personas into whichever tool you're using."
