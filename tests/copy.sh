# A first run clones, copies and excludes.
new_sandbox
write_config ai-rules "$ORIGIN"
sh "$HERE/ai-sync.sh" -C "$PROJECT" >/dev/null

[ -d "$PROJECT/.claude/rules/ai-rules" ] && [ ! -L "$PROJECT/.claude/rules/ai-rules" ] \
  && pass "the entry is a real directory" || fail "the entry is a real directory"

actual=$(cat "$PROJECT/.claude/rules/ai-rules/core/PROJECT")
check "the copy carries the tree" "$actual" "project"

actual=$(grep -c '^/\.claude' "$PROJECT/.git/info/exclude" || true)
check "nothing is written to info/exclude" "$actual" "0"

# The tree is untracked and nothing hides it any more, so `git status` sees it.
# What must stay clean is everything else: ai-sync adds no file of its own to
# the repository and stages nothing.
actual=$(git -C "$PROJECT" status --porcelain -- . ':!.claude' ':!ai-sync.local.json' | wc -l | tr -d ' ')
check "ai-sync stages nothing of its own" "$actual" "0"
drop_sandbox

# A second run changes nothing.
new_sandbox
write_config ai-rules "$ORIGIN"
sh "$HERE/ai-sync.sh" -C "$PROJECT" >/dev/null
sh "$HERE/ai-sync.sh" --force -C "$PROJECT" >/dev/null
actual=$(git -C "$PROJECT" status --porcelain -- . ':!.claude' ':!ai-sync.local.json' | wc -l | tr -d ' ')
check "a second run stages nothing of its own" "$actual" "0"
drop_sandbox

# Without a terminal an existing directory is refused; --force replaces it.
#
# `setsid` is not decoration: ai-sync asks /dev/tty, so on a machine whose
# suite runs from a real terminal this case would block on a prompt instead of
# reporting a refusal. Detaching from the controlling terminal is what makes
# the no-terminal path the one under test everywhere. Where setsid is missing
# the case is skipped out loud rather than run on the wrong branch.
new_sandbox
write_config ai-rules "$ORIGIN"
mkdir -p "$PROJECT/.claude/rules/ai-rules"
printf 'mine\n' > "$PROJECT/.claude/rules/ai-rules/KEEP"
if command -v setsid >/dev/null 2>&1; then
  if setsid sh "$HERE/ai-sync.sh" -C "$PROJECT" >/dev/null 2>&1; then
    fail "an existing directory is refused"
  else
    [ -f "$PROJECT/.claude/rules/ai-rules/KEEP" ] \
      && pass "an existing directory is refused" \
      || fail "an existing directory is refused"
  fi
else
  printf 'SKIP: an existing directory is refused (no setsid to drop the tty)\n' >&2
fi
sh "$HERE/ai-sync.sh" --force -C "$PROJECT" >/dev/null
[ -f "$PROJECT/.claude/rules/ai-rules/KEEP" ] \
  && fail "--force replaces an existing directory" \
  || pass "--force replaces an existing directory"
actual=$(cat "$PROJECT/.claude/rules/ai-rules/core/PROJECT")
check "--force leaves the tree behind" "$actual" "project"
drop_sandbox

# A symlink from the previous mechanism is replaced, and its target survives.
new_sandbox
write_config ai-rules "$ORIGIN"
mkdir -p "$PROJECT/.claude/rules"
ln -s "$SANDBOX/ai-rules/.claude/rules/ai-rules" "$PROJECT/.claude/rules/ai-rules"
sh "$HERE/ai-sync.sh" --force -C "$PROJECT" >/dev/null
[ -L "$PROJECT/.claude/rules/ai-rules" ] \
  && fail "a symlink is replaced by a directory" \
  || pass "a symlink is replaced by a directory"
[ -f "$SANDBOX/ai-rules/.claude/rules/ai-rules/CLAUDE-BOT.md" ] \
  && pass "removing the symlink leaves its target" \
  || fail "removing the symlink leaves its target"
drop_sandbox
