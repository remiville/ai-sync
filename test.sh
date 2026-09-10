#!/bin/sh
# ai-sync test suite. No network: origins are file:// repositories in a temp
# directory. Every test runs against its own HOME so the cache is disposable.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
PASS=0
FAIL=0

fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }
pass() { printf 'ok: %s\n' "$1"; PASS=$((PASS + 1)); }

check() {
  if [ "$2" = "$3" ]; then pass "$1"; else
    fail "$1"
    printf '  expected: %s\n  actual:   %s\n' "$3" "$2" >&2
  fi
}

# A sandbox: $SANDBOX/home is HOME, $SANDBOX/origin is a rules repository
# served over file://, $SANDBOX/project is the consuming project.
new_sandbox() {
  SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/ai-sync-test.XXXXXX")
  export HOME="$SANDBOX/home"
  mkdir -p "$HOME"
  mkdir -p "$SANDBOX/origin/.claude/rules/ai-rules/core"
  printf '# hub\n' > "$SANDBOX/origin/.claude/rules/ai-rules/CLAUDE-BOT.md"
  printf 'project\n' > "$SANDBOX/origin/.claude/rules/ai-rules/core/PROJECT"
  git -C "$SANDBOX/origin" init -q -b main
  git -C "$SANDBOX/origin" add -A
  git -C "$SANDBOX/origin" -c user.email=t@t -c user.name=t commit -qm init
  mkdir -p "$SANDBOX/project"
  git -C "$SANDBOX/project" init -q -b main
  ORIGIN="file://$SANDBOX/origin"
  PROJECT="$SANDBOX/project"
}

write_config() {
  cat > "$PROJECT/ai-sync.local.json" <<EOF
{
  "version": 1,
  "claude": {
    "rules": {
      "$1": "$2"
    }
  }
}
EOF
}

drop_sandbox() { rm -rf "$SANDBOX"; }

. "$HERE/tests/entries.sh"
. "$HERE/tests/link.sh"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
