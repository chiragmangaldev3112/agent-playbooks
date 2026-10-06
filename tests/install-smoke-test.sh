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
printf '# Bug-fix playbook\n\nTrigger words: bug, broken, error.\n\n## Rule\n\nNever edit code to fix a reported bug until you have reproduced it. A fix written against a description is a guess.\n\nWrite tests to the standard in `../quality/reference/test-code-standard.md`.\n' > "$FIXTURE/src/agent-playbooks/core/bug-fix.md"
# A playbook whose job is to commit and push: its generated Claude skill must be user-invoked only.
printf '# Finish-work playbook\n\nTrigger words: finish this, commit and push.\n\n## Rule\n\nFinish work in the open and ask before every step that changes history.\n' > "$FIXTURE/src/agent-playbooks/core/finish-work.md"
# Supporting text, never a skill or rule of its own.
mkdir -p "$FIXTURE/src/agent-playbooks/quality/reference"
printf '# Test-code standard\n\nSupporting text, not a playbook.\n' > "$FIXTURE/src/agent-playbooks/quality/reference/test-code-standard.md"
# Not a playbook -- must never become a generated skill/rule (it did in
# installer 2.2.0, once content 1.28.0 added THIRD_PARTY.md).
printf '# Third-party software\n\nNot a playbook.\n' > "$FIXTURE/src/agent-playbooks/THIRD_PARTY.md"

python3 "$REPO_DIR/tests/support/build_fixture.py" "$FIXTURE"
ssh-keygen -Y sign -f "$WORK/testkey" -n agent-playbooks-release "$FIXTURE/manifest.json" >/dev/null 2>&1

# Runs one case: starts the mock server (with the given extra flags),
# runs install.sh with the given signer line + any extra env, tears the
# server down, and returns install.sh's own exit code. stderr is also
# captured to $LAST_STDERR so a caller can confirm *why* it failed --
# without this, a case that expects failure would also "pass" if install.sh
# failed for a completely unrelated reason (confirmed real: a CI runner
# where the mock server itself was unreachable made every negative test
# here report a false pass, since they only checked "failed + wrote
# nothing," not the actual error).
LAST_STDERR=""
run_case() {
  local port="$1" target="$2" signers="$3" server_flag="$4"
  shift 4
  mkdir -p "$target"
  python3 "$REPO_DIR/tests/support/mock_server.py" "$FIXTURE" "$port" "$server_flag" &
  local server_pid=$!
  sleep 0.5
  local stderr_file="$WORK/last_stderr"
  AGENT_PLAYBOOKS_CHECK_IN_URL="http://127.0.0.1:$port" \
    AGENT_PLAYBOOKS_ID_FILE="$WORK/id" \
    AGENT_PLAYBOOKS_TOOL=none \
    AGENT_PLAYBOOKS_ALLOWED_SIGNERS="$signers" \
    "$@" \
    bash "$REPO_DIR/install.sh" "$target" 2>"$stderr_file"
  local result=$?
  LAST_STDERR="$(cat "$stderr_file")"
  kill "$server_pid" 2>/dev/null || true
  wait "$server_pid" 2>/dev/null || true
  if [[ -z "$LAST_STDERR" ]]; then
    :
  elif grep -q "could not reach the check-in endpoint" "$stderr_file"; then
    echo "  NETWORK: mock server on 127.0.0.1:$port was unreachable -- this case can't have exercised the real check, only the network-failure path." >&2
  fi
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
  check "tampered install rejected for the right reason" \
    "$(grep -q 'does not match the signed manifest' <<< "$LAST_STDERR" && echo yes || echo no)" "yes"
fi

echo "== Test 3: missing manifest is refused =="
t4="$WORK/target4"
if run_case 8904 "$t4" "$ALLOWED_SIGNERS_LINE" "--no-manifest"; then
  check "missing-manifest install should fail" "succeeded" "failed"
else
  check "missing-manifest install rejected" "$([[ -f "$t4/AGENTS.md" ]] && echo "wrote files" || echo "wrote nothing")" "wrote nothing"
  check "missing-manifest install rejected for the right reason" \
    "$(grep -q 'missing its integrity manifest' <<< "$LAST_STDERR" && echo yes || echo no)" "yes"
fi

echo "== Test 4: wrong signing key is rejected =="
t5="$WORK/target5"
if run_case 8905 "$t5" "$WRONG_SIGNERS_LINE" ""; then
  check "wrong-key install should fail" "succeeded" "failed"
else
  check "wrong-key install rejected" "$([[ -f "$t5/AGENTS.md" ]] && echo "wrote files" || echo "wrote nothing")" "wrote nothing"
  check "wrong-key install rejected for the right reason" \
    "$(grep -q 'signature verification failed' <<< "$LAST_STDERR" && echo yes || echo no)" "yes"
fi

echo "== Test 5: --only installs a single playbook =="
t6="$WORK/target6"
if run_case 8906 "$t6" "$ALLOWED_SIGNERS_LINE" "" env AGENT_PLAYBOOKS_ONLY=bug-fix; then
  check "--only installed the requested file" "$([[ -f "$t6/agent-playbooks/core/bug-fix.md" ]] && echo yes || echo no)" "yes"
else
  check "--only install exit code" "failed" "succeeded"
fi

echo "== Test 6: Claude Code artifacts: only real playbooks, persona tools match roles.md =="
t7="$WORK/target7"
if run_case 8907 "$t7" "$ALLOWED_SIGNERS_LINE" "" env AGENT_PLAYBOOKS_TOOL=claude; then
  check "playbook became a skill" "$([[ -f "$t7/.claude/skills/core-bug-fix/SKILL.md" ]] && echo yes || echo no)" "yes"
  check "THIRD_PARTY.md did not become a skill" "$(compgen -G "$t7/.claude/skills/*third*" | wc -l | tr -d ' ')" "0"
  check "implement persona can edit files" "$(grep -c '^tools: .*Edit, Write' "$t7/.claude/agents/feature-builder.md" || true)" "1"
  check "fixing persona can edit files" "$(grep -c '^tools: .*Edit, Write' "$t7/.claude/agents/bug-hunter.md" || true)" "1"
  check "read-only persona stays read-only" "$(grep -c '^tools: Read, Grep, Glob, Bash$' "$t7/.claude/agents/code-reviewer.md" || true)" "1"
  check "skill carries its name" "$(grep -c '^name: core-bug-fix$' "$t7/.claude/skills/core-bug-fix/SKILL.md" || true)" "1"
  check "description says what it is and when to use it" "$(grep -c '^description: "Bug-fix: Never edit code to fix a reported bug until you have reproduced it. Use when: bug, broken, error' "$t7/.claude/skills/core-bug-fix/SKILL.md" || true)" "1"
  check "a push-and-commit playbook is user-invoked only" "$(grep -c '^disable-model-invocation: true$' "$t7/.claude/skills/core-finish-work/SKILL.md" || true)" "1"
  check "an ordinary playbook can be loaded by the model" "$(grep -c 'disable-model-invocation' "$t7/.claude/skills/core-bug-fix/SKILL.md" || true)" "0"
  check "a reference file did not become a skill" "$(compgen -G "$t7/.claude/skills/*reference*" | wc -l | tr -d ' ')" "0"
else
  check "claude-tool install exit code" "failed" "succeeded"
fi

echo "== Test 7: Windows (Git Bash): a jq that writes CRLF line endings must not break the install =="
# jq.exe on Windows ends every line with \r unless given --binary; the stray \r
# made base64 reject the release ("base64: invalid input") for a real user.
# Imitate it: a jq shim that adds \r unless --binary/-b is passed, and a uname
# that reports Git Bash. Without the fix in install.sh this case fails.
winshim="$WORK/winshim"
mkdir -p "$winshim"
REAL_JQ="$(command -v jq)"
cat > "$winshim/jq" <<SHIM
#!/usr/bin/env bash
# Imitates jq.exe: CRLF output unless --binary/-b is given. With
# WIN_JQ_NO_BINARY=1 it imitates a jq too old to know --binary.
args=(); binary=0
for a in "\$@"; do
  if [[ "\$a" == "-b" || "\$a" == "--binary" ]]; then binary=1; else args+=("\$a"); fi
done
if [[ \$binary -eq 1 ]]; then
  if [[ -n "\${WIN_JQ_NO_BINARY:-}" ]]; then echo "jq: Unknown option --binary" >&2; exit 2; fi
  exec "$REAL_JQ" "\${args[@]}"
fi
"$REAL_JQ" "\${args[@]}" | sed \$'s/\$/\\r/'
exit "\${PIPESTATUS[0]}"
SHIM
printf '#!/usr/bin/env bash\necho MINGW64_NT-10.0-26100\n' > "$winshim/uname"
chmod +x "$winshim/jq" "$winshim/uname"
t8="$WORK/target8"
if run_case 8908 "$t8" "$ALLOWED_SIGNERS_LINE" "" env PATH="$winshim:$PATH"; then
  check "Windows-style jq: AGENTS.md installed intact" "$(cat "$t8/AGENTS.md" 2>/dev/null || echo MISSING)" "$(cat "$FIXTURE/src/AGENTS.md")"
  check "Windows-style jq: playbook installed" "$([[ -f "$t8/agent-playbooks/core/bug-fix.md" ]] && echo yes || echo no)" "yes"
else
  check "Windows-style jq install exit code (stderr: $LAST_STDERR)" "failed" "succeeded"
fi

echo "== Test 8: Windows (Git Bash) with a jq that does not know --binary: output is stripped of CR instead =="
t9="$WORK/target9"
if run_case 8909 "$t9" "$ALLOWED_SIGNERS_LINE" "" env PATH="$winshim:$PATH" WIN_JQ_NO_BINARY=1; then
  check "old-jq fallback: AGENTS.md installed intact" "$(cat "$t9/AGENTS.md" 2>/dev/null || echo MISSING)" "$(cat "$FIXTURE/src/AGENTS.md")"
else
  check "old-jq fallback install exit code (stderr: $LAST_STDERR)" "failed" "succeeded"
fi


echo "== Test 9: Cursor rules and Antigravity skills: reference files skipped, richer descriptions =="
t10="$WORK/target10"
if run_case 8910 "$t10" "$ALLOWED_SIGNERS_LINE" "" env AGENT_PLAYBOOKS_TOOL=cursor; then
  check "cursor: playbook became a rule" "$([[ -f "$t10/.cursor/rules/core-bug-fix.mdc" ]] && echo yes || echo no)" "yes"
  check "cursor: reference file did not become a rule" "$(compgen -G "$t10/.cursor/rules/*reference*" | wc -l | tr -d ' ')" "0"
  check "cursor: description has the Use when part" "$(grep -c 'Use when: bug, broken, error' "$t10/.cursor/rules/core-bug-fix.mdc" || true)" "1"
else
  check "cursor install exit code" "failed" "succeeded"
fi
t11="$WORK/target11"
if run_case 8911 "$t11" "$ALLOWED_SIGNERS_LINE" "" env AGENT_PLAYBOOKS_TOOL=antigravity; then
  check "antigravity: playbook became a skill" "$([[ -f "$t11/.agents/skills/core-bug-fix/SKILL.md" ]] && echo yes || echo no)" "yes"
  check "antigravity: reference file did not become a skill" "$(compgen -G "$t11/.agents/skills/*reference*" | wc -l | tr -d ' ')" "0"
else
  check "antigravity install exit code" "failed" "succeeded"
fi

echo "== Test 10: --only pulls in a referenced reference file =="
t12="$WORK/target12"
if run_case 8912 "$t12" "$ALLOWED_SIGNERS_LINE" "" env AGENT_PLAYBOOKS_ONLY=bug-fix; then
  check "--only: the playbook is installed" "$([[ -f "$t12/agent-playbooks/core/bug-fix.md" ]] && echo yes || echo no)" "yes"
  check "--only: the reference file it points to comes with it" "$([[ -f "$t12/agent-playbooks/quality/reference/test-code-standard.md" ]] && echo yes || echo no)" "yes"
else
  check "--only with a reference install exit code" "failed" "succeeded"
fi

echo "== Test 11: the real trusted release keys are the three we expect =="
# The default ALLOWED_SIGNERS is what every real install trusts. Read it out of install.sh (not the
# test override) and pin it: three well-formed lines, and the newest key's fingerprint is the one the
# maintainer generated on 2026-10-06. A mistyped or truncated key would make every release unverifiable.
# shellcheck disable=SC2016 # the ${...} in the sed pattern is literal text from install.sh, not an expansion
signers_block="$(awk '/^ALLOWED_SIGNERS=/{p=1} p{print} /\}"$/{if(p) exit}' "$REPO_DIR/install.sh" | sed 's/^ALLOWED_SIGNERS="\${AGENT_PLAYBOOKS_ALLOWED_SIGNERS:-//; s/}"$//')"
check "three trusted keys" "$(printf '%s\n' "$signers_block" | grep -c '^release@agent-playbooks ssh-ed25519 ')" "3"
check "every line is well formed" "$(printf '%s\n' "$signers_block" | grep -cE '^release@agent-playbooks ssh-ed25519 [A-Za-z0-9+/=]+ agent-playbooks-release$')" "3"
newest_key="$(printf '%s\n' "$signers_block" | tail -1 | cut -d' ' -f2-)"
printf '%s\n' "$newest_key" > "$WORK/newest.pub"
check "newest trusted key has the expected fingerprint" "$(ssh-keygen -lf "$WORK/newest.pub" 2>/dev/null | awk '{print $2}')" "SHA256:0+6g7WwxRhZMx84WpICeN6d5MdtLhmowi+Fylz20bUE"

echo
echo "== $PASS passed, $FAIL failed =="
[[ $FAIL -eq 0 ]]
