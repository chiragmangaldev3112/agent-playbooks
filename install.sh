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
# scripts, e.g. demo-video.md's).
#
# Usage:
#   ./install.sh                # installs into the current directory
#   ./install.sh /path/to/repo  # installs into that directory instead
#
# Set AGENT_PLAYBOOKS_TOOL=claude|cursor|antigravity|codex|copilot|none to
# skip the interactive tool prompt (e.g. for a non-interactive/CI install).
#
# After this finishes, point your AI coding agent at
# agent-playbooks/project-bootstrap.md in the target project -- the smart,
# context-aware pass that grounds AGENTS.md in the target's real stack and
# wires the safety guardrail + personas into whichever tool you use there.

set -euo pipefail

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
payload="$(jq -n --arg id "$local_id" '{p_id: $id}')"
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

if [[ ! -f "$WORKDIR/AGENTS.md" || ! -d "$WORKDIR/agent-playbooks" ]]; then
  echo "Error: fetched release doesn't contain AGENTS.md / agent-playbooks/." >&2
  exit 1
fi

cp "$WORKDIR/AGENTS.md" "$TARGET_DIR/AGENTS.md"
cp -R "$WORKDIR/agent-playbooks" "$TARGET_DIR/agent-playbooks"
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
  done < <(find "$pb_dir" -name "*.md" ! -name "README.md" ! -name "EXAMPLES.md" ! -path "*/examples/*" -print0)

  local personas='bug-hunter|Reproduces a reported bug with a real, runnable failing test before proposing any fix.
feature-builder|Implements a feature test-first: failing test from the spec, implement until it passes.
code-reviewer|Reviews a diff for correctness, security, and convention adherence.
test-writer|Adds test coverage for existing, untested code.
manual-exploratory-tester|Explores a running app or change the way a human tester would.
project-bootstrapper|Onboards an agent to an unfamiliar repo, grounding every claim in real files.'
  local n=0 pslug pdesc
  while IFS='|' read -r pslug pdesc; do
    [[ -z "$pslug" ]] && continue
    printf -- '---\nname: %s\ndescription: "%s"\ntools: Read, Grep, Glob, Bash\n---\n\nFollow the persona defined in `agent-playbooks/autonomy/roles.md` exactly (the section matching this agent'"'"'s name).\n' \
      "$pslug" "$pdesc" > "$agents_dir/$pslug.md"
    n=$((n + 1))
  done <<< "$personas"
  echo "Generated $count Claude Code Skills (.claude/skills/) and $n sub-agents (.claude/agents/)." >&2
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
  done < <(find "$pb_dir" -name "*.md" ! -name "README.md" ! -name "EXAMPLES.md" ! -path "*/examples/*" -print0)
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
  done < <(find "$pb_dir" -name "*.md" ! -name "README.md" ! -name "EXAMPLES.md" ! -path "*/examples/*" -print0)
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

echo "Installed:"
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
echo "follow agent-playbooks/project-bootstrap.md. That pass grounds"
echo "AGENTS.md in the real stack it finds there, and wires the safety"
echo "guardrail + roles.md personas into whichever tool you're using."
