#!/usr/bin/env bash
# Installs AGENTS.md + agent-playbooks/ into a target project. Zero setup:
# no account, no token, nothing to ask the maintainer for -- just run it.
# This repo does not carry the playbook content itself; it fetches the
# current release from a check-in endpoint on each install (see README.md
# for exactly what that does and doesn't do). Requires curl, jq, tar,
# base64 (standard on macOS/Linux).
#
# Usage:
#   ./install.sh                # installs into the current directory
#   ./install.sh /path/to/repo  # installs into that directory instead
#
# After this finishes, point your AI coding agent at
# agent-playbooks/project-bootstrap.md in the target project -- the smart,
# context-aware pass that grounds AGENTS.md in the target's real stack and
# wires the safety guardrail + personas into whichever tool you use there.

set -euo pipefail

TARGET_DIR="${1:-.}"
CHECK_IN_URL="${AGENT_PLAYBOOKS_CHECK_IN_URL:-https://cjogceoqhgjzpalbqpga.supabase.co/functions/v1/check-in}"
ID_FILE="${AGENT_PLAYBOOKS_ID_FILE:-$HOME/.agent-playbooks-id}"

for cmd in curl jq tar base64; do
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

archive_b64="$(echo "$response" | jq -r '.[0].archive_base64 // empty')"
if [[ -z "$archive_b64" ]]; then
  echo "Error: no release archive returned. No published release yet?" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "$archive_b64" | base64 -d > "$WORKDIR/release.tar.gz" || {
  echo "Error: could not decode the fetched archive." >&2
  exit 1
}
tar -xzf "$WORKDIR/release.tar.gz" -C "$WORKDIR" || {
  echo "Error: could not extract the fetched archive." >&2
  exit 1
}
if [[ ! -f "$WORKDIR/AGENTS.md" || ! -d "$WORKDIR/agent-playbooks" ]]; then
  echo "Error: extracted archive doesn't contain AGENTS.md / agent-playbooks/." >&2
  exit 1
fi

cp "$WORKDIR/AGENTS.md" "$TARGET_DIR/AGENTS.md"
cp -R "$WORKDIR/agent-playbooks" "$TARGET_DIR/agent-playbooks"
chmod +x "$TARGET_DIR"/agent-playbooks/scripts/*.sh 2>/dev/null || true

notice="$(echo "$response" | jq -r '.[0].notice // empty')"
[[ -n "$notice" ]] && echo "Notice: $notice"

echo "Installed:"
echo "  $TARGET_DIR/AGENTS.md"
echo "  $TARGET_DIR/agent-playbooks/"
echo
echo "Next step: open your AI coding tool in that project and ask it to"
echo "follow agent-playbooks/project-bootstrap.md. That pass grounds"
echo "AGENTS.md in the real stack it finds there, and wires the safety"
echo "guardrail + roles.md personas into whichever tool you're using."
