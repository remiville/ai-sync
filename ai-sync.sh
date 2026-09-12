#!/bin/sh
# ai-sync — copy AI directive trees into a project from a shared git cache.
#
# Consumes ai-sync.local.json; never writes it. The rules repository is the
# file's content, not an argument: whoever sets the project up puts it there.
set -eu

CACHE="${AI_SYNC_CACHE:-$HOME/.config/ai-sync/repos}"
CONFIG_NAME="ai-sync.local.json"

# "<entry> <url>" per line, from the "claude"."rules" object.
#
# The nested keys hold objects and "version" holds a number, so a pattern
# matching only string-valued keys yields exactly the entries. This is safe
# because the file is generated from a fixed template and never patched; a file
# that does not match the canonical form is refused rather than guessed at.
read_entries() {
  config=$1
  [ -f "$config" ] || { echo "ai-sync: no $CONFIG_NAME in the project" >&2; return 1; }
  grep -q '"claude"' "$config" && grep -q '"rules"' "$config" || {
    echo "ai-sync: $config is not in canonical form" >&2; return 1
  }
  out=$(sed -n \
    's/^[[:space:]]\{1,\}"\([A-Za-z0-9._-]\{1,\}\)"[[:space:]]*:[[:space:]]*"\([^"]\{1,\}\)".*$/\1 \2/p' \
    "$config")
  [ -n "$out" ] || { echo "ai-sync: $config declares no entry" >&2; return 1; }
  printf '%s\n' "$out"
}

# Sourced by the test suite to exercise one function at a time.
[ "${AI_SYNC_LIB:-}" = 1 ] && return 0

# The repository's info/exclude — never "$project/.git/info/exclude": in a
# worktree .git is a file and the exclude lives in the main gitdir.
exclude_path() {
  d=$(git -C "$1" rev-parse --git-common-dir 2>/dev/null) || return 1
  case "$d" in /*) ;; *) d="$1/$d" ;; esac
  printf '%s/info/exclude\n' "$d"
}

exclude() {
  f=$(exclude_path "$1") || {
    echo "ai-sync: $1 is not a git repository, skipping exclude" >&2
    return 0
  }
  mkdir -p "$(dirname "$f")"
  [ -f "$f" ] || : > "$f"
  grep -qxF "$2" "$f" || printf '%s\n' "$2" >> "$f"
}

fetch_repo() {
  url=$1
  name=$(basename "$url" .git)
  repo="$CACHE/$name"
  if [ -d "$repo/.git" ]; then
    [ "$UPDATE" = 1 ] && git -C "$repo" pull --ff-only --quiet
  else
    mkdir -p "$CACHE"
    git clone --quiet "$url" "$repo"
  fi
  printf '%s\n' "$repo"
}

# The copy is disposable and the clone is the source, so a refresh deletes
# before it copies: `cp` over the old tree would leave a file that upstream
# removed in place forever, and nothing reads a file that is meant to be gone.
#
# What to do about an existing destination is decided by the caller, because
# only the caller knows whose directory it is. `--update` and `--force` replace;
# a terminal is asked; anything else refuses and says which flag to pass. The
# last case is the one that matters: claude-bot runs this with its output
# captured and the chat façade has no terminal at all, so a prompt they could
# reach would hang instead of protecting them.
#
# The question goes to /dev/tty and not to stdin, because this function runs
# inside `read_entries | while read`, where stdin is the pipe feeding the loop.
# `[ -t 0 ]` there is false whatever the caller is — the prompt would be dead
# code — and a `read` from stdin would swallow the next entry instead of an
# answer. /dev/tty is the terminal or it is nothing, which is exactly the test.
copy_entry() {
  project=$1 entry=$2 url=$3
  repo=$(fetch_repo "$url")
  src="$repo/.claude/rules/$entry"
  [ -d "$src" ] || {
    echo "ai-sync: $url has no entry '$entry' at .claude/rules/$entry" >&2
    return 1
  }
  dst="$project/.claude/rules/$entry"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ "$FORCE" = 1 ] || [ "$UPDATE" = 1 ]; then
      :
    elif { : < /dev/tty; } 2>/dev/null; then
      printf 'ai-sync: replace %s? [y/N] ' "$dst" > /dev/tty
      read -r answer < /dev/tty
      case $answer in
        y|Y) ;;
        *) echo "ai-sync: kept $dst" >&2; return 1 ;;
      esac
    else
      echo "ai-sync: $dst exists — pass --force to replace it" >&2
      return 1
    fi
  fi
  # On a symlink this removes the link and not its target, which is what
  # migrates a project linked by the previous mechanism.
  rm -rf "$dst"
  mkdir -p "$project/.claude/rules"
  cp -a "$src/." "$dst/"
  exclude "$project" "/.claude/rules/$entry"
  echo "copied $entry <- $src"
}

usage() { echo "usage: ai-sync.sh [-C DIR] [--update] [--force]" >&2; exit 2; }

PROJECT_DIR=.
UPDATE=0
FORCE=0
while [ $# -gt 0 ]; do
  case $1 in
    -C) [ $# -ge 2 ] || usage; PROJECT_DIR=$2; shift 2 ;;
    --update) UPDATE=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done

PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd)
read_entries "$PROJECT_DIR/$CONFIG_NAME" | while read -r entry url; do
  copy_entry "$PROJECT_DIR" "$entry" "$url"
done
exclude "$PROJECT_DIR" "/$CONFIG_NAME"
