#!/bin/sh
# Bootstrap ai-sync, then copy the directives in.
#
#   curl -fsSL .../install.sh | sh
#   curl -fsSL .../install.sh | sh -s -- --rules git@github.com:you/your-rules.git
#
# The first form is the normal one: the config already exists and this only
# locates ai-sync and hands off. The second seeds a config where there is none,
# which is the only case in which this script writes that file. The config is
# the user's, at ~/.config/ai-sync/, unless -C names a project.
set -eu

REPO_URL="${AI_SYNC_REPO:-https://github.com/remiville/ai-sync.git}"
CACHE="${AI_SYNC_CACHE:-$HOME/.config/ai-sync/repos}"
CONFIG_NAME="ai-sync.local.json"

DEST=""
RULES=""
ENTRY=""
while [ $# -gt 0 ]; do
  case $1 in
    -C) [ $# -ge 2 ] || exit 2; DEST=$2; shift 2 ;;
    --rules) [ $# -ge 2 ] || exit 2; RULES=$2; shift 2 ;;
    --entry) [ $# -ge 2 ] || exit 2; ENTRY=$2; shift 2 ;;
    *) echo "usage: install.sh [-C DIR] [--rules URL] [--entry NAME]" >&2; exit 2 ;;
  esac
done

command -v git >/dev/null 2>&1 || { echo "install.sh: git is required" >&2; exit 1; }

# Like ai-sync.sh: the home is the default and -C is the opt-in for a project.
if [ -n "$DEST" ]; then
  DEST=$(cd "$DEST" && pwd)
  config="$DEST/$CONFIG_NAME"
else
  config="$HOME/.config/ai-sync/$CONFIG_NAME"
  mkdir -p "$(dirname "$config")"
fi

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
  echo "install.sh: no config at $config — pass --rules <url> to create one." >&2
  exit 1
fi

mkdir -p "$CACHE"
if [ -d "$CACHE/ai-sync/.git" ]; then
  git -C "$CACHE/ai-sync" pull --ff-only --quiet
else
  git clone --quiet "$REPO_URL" "$CACHE/ai-sync"
fi

if [ -n "$DEST" ]; then
  exec sh "$CACHE/ai-sync/ai-sync.sh" -C "$DEST"
fi
exec sh "$CACHE/ai-sync/ai-sync.sh"
