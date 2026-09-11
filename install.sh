#!/bin/sh
# Bootstrap ai-sync, then link the project's directives.
#
#   curl -fsSL .../install.sh | sh
#   curl -fsSL .../install.sh | sh -s -- --rules git@github.com:you/your-rules.git
#
# The first form is the normal one: the project already carries an
# ai-sync.local.json and this only locates ai-sync and hands off. The second
# seeds a project that has none, which is the only case in which this script
# writes that file.
set -eu

REPO_URL="${AI_SYNC_REPO:-https://github.com/remiville/ai-sync.git}"
CACHE="${AI_SYNC_CACHE:-$HOME/.config/ai-sync/repos}"
CONFIG_NAME="ai-sync.local.json"

PROJECT_DIR=.
RULES=""
ENTRY=""
while [ $# -gt 0 ]; do
  case $1 in
    -C) [ $# -ge 2 ] || exit 2; PROJECT_DIR=$2; shift 2 ;;
    --rules) [ $# -ge 2 ] || exit 2; RULES=$2; shift 2 ;;
    --entry) [ $# -ge 2 ] || exit 2; ENTRY=$2; shift 2 ;;
    *) echo "usage: install.sh [-C DIR] [--rules URL] [--entry NAME]" >&2; exit 2 ;;
  esac
done

command -v git >/dev/null 2>&1 || { echo "install.sh: git is required" >&2; exit 1; }
PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd)
config="$PROJECT_DIR/$CONFIG_NAME"

if [ -f "$config" ]; then
  if [ -n "$RULES" ] && ! grep -qF "\"$RULES\"" "$config"; then
    echo "install.sh: $config already names a different rules repository." >&2
    echo "            Edit it, or drop --rules to use what it holds." >&2
    exit 1
  fi
elif [ -n "$RULES" ]; then
  [ -n "$ENTRY" ] || ENTRY=$(basename "$RULES" .git)
  cat > "$config" <<EOF
{
  "version": 1,
  "claude": {
    "rules": {
      "$ENTRY": "$RULES"
    }
  }
}
EOF
  echo "wrote $config"
else
  echo "install.sh: no $CONFIG_NAME here — pass --rules <url> to create one." >&2
  exit 1
fi

mkdir -p "$CACHE"
if [ -d "$CACHE/ai-sync/.git" ]; then
  git -C "$CACHE/ai-sync" pull --ff-only --quiet
else
  git clone --quiet "$REPO_URL" "$CACHE/ai-sync"
fi

exec sh "$CACHE/ai-sync/ai-sync.sh" -C "$PROJECT_DIR"
