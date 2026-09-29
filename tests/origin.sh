# A cached clone is named after its URL's basename, so a clone made from
# another URL for the same name — the same repository over https, a fork, an
# earlier attempt — sits where the configured one is expected.

# Make $SANDBOX/other/ai-rules, a repository the cache is left pointing at,
# holding "$1" and a branch "stale" only it has.
other_repository() {
  other="$SANDBOX/other/ai-rules"
  mkdir -p "$other/.claude/rules/ai-rules/core"
  printf '%s\n' "$1" > "$other/.claude/rules/ai-rules/core/PROJECT"
  git -C "$other" init -q -b main
  git -C "$other" add -A
  git -C "$other" -c user.email=t@t -c user.name=t commit -qm other
  git -C "$other" branch stale
  OTHER="file://$other"
}

# The case reported: a branch clone left by an earlier URL, whose origin does
# not have the branch.
new_sandbox
other_repository other
git -C "$SANDBOX/ai-rules" checkout -q -b story/x
git -C "$SANDBOX/ai-rules" checkout -q main
mkdir -p "$HOME/.config/ai-sync/repos"
git clone -q "$OTHER" "$HOME/.config/ai-sync/repos/ai-rules@story~x"
write_config ai-rules "$ORIGIN#story/x"
if sh "$HERE/ai-sync.sh" -C "$PROJECT" --update >/dev/null 2>"$SANDBOX/err"; then
  actual=$(cat "$PROJECT/.claude/rules/ai-rules/core/PROJECT")
  check "a ref clone from another URL is replaced" "$actual" "project"
else
  fail "a ref clone from another URL is replaced"
  sed 's/^/  /' "$SANDBOX/err" >&2
fi
drop_sandbox

# The unpinned clone, where the other repository's history is unrelated and
# a fast-forward pull cannot reach the configured one.
new_sandbox
other_repository other
mkdir -p "$HOME/.config/ai-sync/repos"
git clone -q "$OTHER" "$HOME/.config/ai-sync/repos/ai-rules"
write_config ai-rules "$ORIGIN"
sh "$HERE/ai-sync.sh" -C "$PROJECT" --update >/dev/null 2>&1 || :
actual=$(cat "$PROJECT/.claude/rules/ai-rules/core/PROJECT" 2>/dev/null || :)
check "an unpinned clone from another URL is replaced on --update" "$actual" "project"
drop_sandbox

# A bare run reads the cache without fetching, and must not copy the other
# repository's content either.
new_sandbox
other_repository other
mkdir -p "$HOME/.config/ai-sync/repos"
git clone -q "$OTHER" "$HOME/.config/ai-sync/repos/ai-rules"
write_config ai-rules "$ORIGIN"
sh "$HERE/ai-sync.sh" -C "$PROJECT" >/dev/null 2>&1 || :
actual=$(cat "$PROJECT/.claude/rules/ai-rules/core/PROJECT" 2>/dev/null || :)
check "a clone from another URL is replaced on a bare run" "$actual" "project"
drop_sandbox

# Nothing of the other remote survives: a branch only it had is refused, not
# resolved from a remote-tracking ref left in the clone.
new_sandbox
other_repository other
mkdir -p "$HOME/.config/ai-sync/repos"
git clone -q "$OTHER" "$HOME/.config/ai-sync/repos/ai-rules@stale"
write_config ai-rules "$ORIGIN#stale"
if sh "$HERE/ai-sync.sh" -C "$PROJECT" --update >/dev/null 2>&1; then
  fail "a branch only the previous origin had is refused"
else
  pass "a branch only the previous origin had is refused"
fi
drop_sandbox

# The comparison is on the URL as configured: an insteadOf rule rewriting it
# must not make a matching clone look foreign, which would re-clone every run.
new_sandbox
git config --global "url.file://$SANDBOX/.insteadOf" "alias:x/"
write_config ai-rules "alias:x/ai-rules"
sh "$HERE/ai-sync.sh" -C "$PROJECT" >/dev/null
touch "$HOME/.config/ai-sync/repos/ai-rules/.git/marker"
sh "$HERE/ai-sync.sh" -C "$PROJECT" --update >/dev/null
[ -f "$HOME/.config/ai-sync/repos/ai-rules/.git/marker" ] \
  && pass "a URL rewritten by insteadOf keeps its clone" \
  || fail "a URL rewritten by insteadOf keeps its clone"
drop_sandbox

# A directory left without .git — an interrupted clone — does not block the
# next one.
new_sandbox
mkdir -p "$HOME/.config/ai-sync/repos/ai-rules/leftover"
write_config ai-rules "$ORIGIN"
sh "$HERE/ai-sync.sh" -C "$PROJECT" >/dev/null 2>&1 || :
actual=$(cat "$PROJECT/.claude/rules/ai-rules/core/PROJECT" 2>/dev/null || :)
check "a cache directory without .git is replaced" "$actual" "project"
drop_sandbox
