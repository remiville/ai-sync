#!/bin/sh
# Bootstrap ai-sync, then copy the directives in.
#
#   curl -fsSL .../install.sh | sh
#   curl -fsSL .../install.sh | sh -s -- --rules git@github.com:you/your-rules.git
#   curl -fsSL .../install.sh | sh -s -- --rules git@github.com:you/your-rules.git#v2
#
# The first form is the normal one: the config already exists and this only
# locates ai-sync and hands off. The second seeds a config where there is none,
# or adds the repository to the one that exists; those are the only cases in
# which this script writes that file. The config is the user's, at
# ~/.config/ai-sync/, unless -C names a project.
#
# "URL#REF" names a branch, a tag or a commit. It is stored as written, so the
# config is what tells ai-sync.sh --update to follow that branch or keep that
# pin; the entry name comes from the URL alone.
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
    *) echo "usage: install.sh [-C DIR] [--rules URL[#REF]] [--entry NAME]" >&2; exit 2 ;;
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

# The config from "<entry> <url>" lines on stdin. This is the only template:
# ai-sync.sh parses the file line by line and relies on this exact shape.
render_config() {
  printf '{\n  "version": 1,\n  "claude": {\n    "rules": {\n'
  first=1
  while read -r e u; do
    [ "$first" = 1 ] || printf ',\n'
    printf '      "%s": "%s"' "$e" "$u"
    first=0
  done
  printf '\n    }\n  }\n}\n'
}

# "<entry> <url>" per line — the same pattern as ai-sync.sh's read_entries,
# which this script cannot source: it runs before ai-sync is cloned.
config_entries() {
  sed -n \
    's/^[[:space:]]\{1,\}"\([A-Za-z0-9._-]\{1,\}\)"[[:space:]]*:[[:space:]]*"\([^"]\{1,\}\)".*$/\1 \2/p' \
    "$1"
}

[ -n "$RULES" ] && [ -z "$ENTRY" ] && ENTRY=$(basename "${RULES%%#*}" .git)

if [ -f "$config" ] && [ -n "$RULES" ]; then
  entries=$(config_entries "$config")
  if printf '%s\n' "$entries" | cut -d' ' -f2 | grep -qxF "$RULES"; then
    :
  elif printf '%s\n' "$entries" | cut -d' ' -f1 | grep -qxF "$ENTRY"; then
    echo "install.sh: $config already has an entry '$ENTRY' for another repository or ref." >&2
    echo "            Pass --entry to name this one differently, or edit the file." >&2
    exit 1
  # Rewriting regenerates the whole file, so it is done only when the file is
  # what the template would produce: anything else in it would be lost.
  elif [ "$(printf '%s\n' "$entries" | render_config)" != "$(cat "$config")" ]; then
    echo "install.sh: $config is not in the form install.sh writes." >&2
    echo "            Add \"$ENTRY\": \"$RULES\" to it by hand." >&2
    exit 1
  else
    printf '%s\n%s %s\n' "$entries" "$ENTRY" "$RULES" | render_config > "$config.tmp"
    mv "$config.tmp" "$config"
    echo "added $ENTRY to $config"
  fi
elif [ -f "$config" ]; then
  :
elif [ -n "$RULES" ]; then
  printf '%s %s\n' "$ENTRY" "$RULES" | render_config > "$config"
  echo "wrote $config"
else
  echo "install.sh: no config at $config — pass --rules <url> to create one." >&2
  exit 1
fi

# A clone of another AI_SYNC_REPO would be pulled from that other origin and
# its code run in place of this one; a directory without .git is no clone at
# all. Either is replaced, as ai-sync.sh's is_clone_of does for the rules
# clones, which this script cannot source. The raw config value is compared,
# because `remote get-url` applies insteadOf rewriting.
mkdir -p "$CACHE"
if [ -d "$CACHE/ai-sync/.git" ] &&
   [ "$(git -C "$CACHE/ai-sync" config --get remote.origin.url)" = "$REPO_URL" ]; then
  git -C "$CACHE/ai-sync" pull --ff-only --quiet
else
  rm -rf "$CACHE/ai-sync"
  git clone --quiet "$REPO_URL" "$CACHE/ai-sync"
fi

# Running the installer is asking for the current directives, so the hand-off
# pulls and replaces. Without --update a copy already in place is asked about,
# or refused with no terminal, and that stops before the entries after it.
if [ -n "$DEST" ]; then
  exec sh "$CACHE/ai-sync/ai-sync.sh" -C "$DEST" --update
fi
exec sh "$CACHE/ai-sync/ai-sync.sh" --update
