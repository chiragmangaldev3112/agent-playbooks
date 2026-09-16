#!/usr/bin/env bash
# End-to-end test for install.sh against a local mock check-in server --
# no network, no real signing key (that never leaves the maintainer's
# machine; see maintainer/package-release.sh in the private source). Signs
# fixtures with a throwaway key and points install.sh at it via
# AGENT_PLAYBOOKS_ALLOWED_SIGNERS, the one override that exists solely for
# this test.
#
# Requires: bash, python3, jq, curl, ssh-keygen (all present on GitHub
# Actions' ubuntu-latest and ordinary macOS/Linux dev machines).
#
# Usage: ./tests/install-smoke-test.sh

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
check() {
  local desc="$1" got="$2" want="$3"
  if [[ "$got" == "$want" ]]; then
    echo "  ok   - $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL - $desc (got: $got, want: $want)"
    FAIL=$((FAIL + 1))
  fi
}

echo "== Building fixture release + throwaway signing key =="
ssh-keygen -t ed25519 -N "" -C "test" -f "$WORK/testkey" >/dev/null
ssh-keygen -t ed25519 -N "" -C "wrong" -f "$WORK/wrongkey" >/dev/null
ALLOWED_SIGNERS_LINE="release@agent-playbooks $(cat "$WORK/testkey.pub")"
WRONG_SIGNERS_LINE="release@agent-playbooks $(cat "$WORK/wrongkey.pub")"

FIXTURE="$WORK/fixture"
mkdir -p "$FIXTURE/src/agent-playbooks/core"
printf '# AGENTS.md fixture\n\nHello agent.\n' > "$FIXTURE/src/AGENTS.md"
printf '9.9.9\n' > "$FIXTURE/src/agent-playbooks/VERSION"
printf '# bug-fix\n\nTrigger: test fixture only.\n' > "$FIXTURE/src/agent-playbooks/core/bug-fix.md"

python3 "$REPO_DIR/tests/support/build_fixture.py" "$FIXTURE"
ssh-keygen -Y sign -f "$WORK/testkey" -n agent-playbooks-release "$FIXTURE/manifest.json" >/dev/null 2>&1

# Runs one case: starts the mock server (with the given extra flags),
# runs install.sh with the given signer line + any extra env, tears the
# server down, and returns install.sh's own exit code.
run_case() {
  local port="$1" target="$2" signers="$3" server_flag="$4"
  shift 4
  mkdir -p "$target"
  python3 "$REPO_DIR/tests/support/mock_server.py" "$FIXTURE" "$port" "$server_flag" &
  local server_pid=$!
  sleep 0.5
  AGENT_PLAYBOOKS_CHECK_IN_URL="http://127.0.0.1:$port" \
    AGENT_PLAYBOOKS_ID_FILE="$WORK/id" \
    AGENT_PLAYBOOKS_TOOL=none \
    AGENT_PLAYBOOKS_ALLOWED_SIGNERS="$signers" \
    "$@" \
    bash "$REPO_DIR/install.sh" "$target"
  local result=$?
  kill "$server_pid" 2>/dev/null || true
  wait "$server_pid" 2>/dev/null || true
  return $result
}

echo "== Test 1: clean install succeeds and content matches =="
t1="$WORK/target1"
if run_case 8901 "$t1" "$ALLOWED_SIGNERS_LINE" ""; then
  check "AGENTS.md installed" "$(cat "$t1/AGENTS.md" 2>/dev/null || echo MISSING)" "$(cat "$FIXTURE/src/AGENTS.md")"
  check "playbook installed" "$([[ -f "$t1/agent-playbooks/core/bug-fix.md" ]] && echo yes || echo no)" "yes"
else
  check "clean install exit code" "failed" "succeeded"
fi

echo "== Test 2: tampered content is rejected, nothing written =="
t2="$WORK/target2"
if run_case 8902 "$t2" "$ALLOWED_SIGNERS_LINE" "--tamper"; then
  check "tampered install should fail" "succeeded" "failed"
else
  check "tampered install rejected" "$([[ -f "$t2/AGENTS.md" ]] && echo "wrote files" || echo "wrote nothing")" "wrote nothing"
fi

echo "== Test 3: legitimately watermarked AGENTS.md still installs =="
t3="$WORK/target3"
if run_case 8903 "$t3" "$ALLOWED_SIGNERS_LINE" "--watermark"; then
  check "watermarked install succeeds" "$(grep -c '<!-- ref:' "$t3/AGENTS.md" 2>/dev/null || echo 0)" "1"
else
  check "watermarked install should succeed" "failed" "succeeded"
fi

echo "== Test 4: missing manifest is refused =="
t4="$WORK/target4"
if run_case 8904 "$t4" "$ALLOWED_SIGNERS_LINE" "--no-manifest"; then
  check "missing-manifest install should fail" "succeeded" "failed"
else
  check "missing-manifest install rejected" "$([[ -f "$t4/AGENTS.md" ]] && echo "wrote files" || echo "wrote nothing")" "wrote nothing"
fi

echo "== Test 5: wrong signing key is rejected =="
t5="$WORK/target5"
if run_case 8905 "$t5" "$WRONG_SIGNERS_LINE" ""; then
  check "wrong-key install should fail" "succeeded" "failed"
else
  check "wrong-key install rejected" "$([[ -f "$t5/AGENTS.md" ]] && echo "wrote files" || echo "wrote nothing")" "wrote nothing"
fi

echo "== Test 6: --only installs a single playbook =="
t6="$WORK/target6"
if run_case 8906 "$t6" "$ALLOWED_SIGNERS_LINE" "" env AGENT_PLAYBOOKS_ONLY=bug-fix; then
  check "--only installed the requested file" "$([[ -f "$t6/agent-playbooks/core/bug-fix.md" ]] && echo yes || echo no)" "yes"
else
  check "--only install exit code" "failed" "succeeded"
fi

echo
echo "== $PASS passed, $FAIL failed =="
[[ $FAIL -eq 0 ]]
