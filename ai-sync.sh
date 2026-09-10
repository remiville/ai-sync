#!/bin/sh
# ai-sync — link AI directive trees into a project from a shared git cache.
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

echo "ai-sync: not implemented" >&2
exit 1
