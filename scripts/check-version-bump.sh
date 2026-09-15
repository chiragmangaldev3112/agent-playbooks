#!/usr/bin/env bash
# Pre-commit check: a commit changing install.sh must also bump VERSION
# and add an INSTALLER_CHANGELOG.md entry, in the same commit. Enforced,
# not just a habit to remember -- mirrors
# ../../maintainer/check-version-bump.sh in the private source repo, but
# scoped to install.sh specifically rather than to all tracked files here,
# since CHANGELOG.md/EXAMPLES.md/FLOWS.md/README.md changes in this repo
# are routine content-sync commits, not installer releases.
#
# Install (not tracked by git -- .git/hooks/ never is -- so re-link after
# a fresh clone):
#   ln -sf ../../scripts/check-version-bump.sh .git/hooks/pre-commit
#
# Exit 0 = commit proceeds. Exit 1 = blocked, reason on stderr.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

staged="$(git diff --cached --name-only)"

installer_changed=0
version_changed=0
changelog_changed=0

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  case "$f" in
    VERSION) version_changed=1 ;;
    INSTALLER_CHANGELOG.md) changelog_changed=1 ;;
    install.sh) installer_changed=1 ;;
  esac
done <<< "$staged"

if [[ $installer_changed -eq 1 && ( $version_changed -eq 0 || $changelog_changed -eq 0 ) ]]; then
  echo "Blocked: this commit changes install.sh but doesn't bump VERSION" >&2
  echo "and add an INSTALLER_CHANGELOG.md entry in the same commit." >&2
  echo "" >&2
  echo "Bump VERSION and add an INSTALLER_CHANGELOG.md entry (see its" >&2
  echo "existing entries for the format), then stage both and commit again." >&2
  exit 1
fi

exit 0
