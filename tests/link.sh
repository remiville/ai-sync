# A first run clones, links and excludes.
new_sandbox
write_config ai-rules "$ORIGIN"
sh "$HERE/ai-sync.sh" -C "$PROJECT" >/dev/null

[ -L "$PROJECT/.claude/rules/ai-rules" ] \
  && pass "the entry is a symlink" || fail "the entry is a symlink"

actual=$(cat "$PROJECT/.claude/rules/ai-rules/core/PROJECT")
check "the link reaches the tree" "$actual" "project"

actual=$(cat "$SANDBOX/project/.git/info/exclude" | grep -c '^/\.claude/rules/ai-rules$')
check "the link is excluded" "$actual" "1"

actual=$(cat "$SANDBOX/project/.git/info/exclude" | grep -c '^/ai-sync\.local\.json$')
check "the config is excluded" "$actual" "1"

actual=$(git -C "$PROJECT" status --porcelain | wc -l | tr -d ' ')
check "the working tree stays clean" "$actual" "0"
drop_sandbox

# A second run changes nothing.
new_sandbox
write_config ai-rules "$ORIGIN"
sh "$HERE/ai-sync.sh" -C "$PROJECT" >/dev/null
sh "$HERE/ai-sync.sh" -C "$PROJECT" >/dev/null
actual=$(grep -c '^/\.claude/rules/ai-rules$' "$SANDBOX/project/.git/info/exclude")
check "a second run does not duplicate the exclude" "$actual" "1"
actual=$(git -C "$PROJECT" status --porcelain | wc -l | tr -d ' ')
check "a second run leaves the tree clean" "$actual" "0"
drop_sandbox

# A real directory in the way is refused, never replaced.
new_sandbox
write_config ai-rules "$ORIGIN"
mkdir -p "$PROJECT/.claude/rules/ai-rules"
printf 'mine\n' > "$PROJECT/.claude/rules/ai-rules/KEEP"
if sh "$HERE/ai-sync.sh" -C "$PROJECT" >/dev/null 2>&1; then
  fail "an existing directory is refused"
else
  [ -f "$PROJECT/.claude/rules/ai-rules/KEEP" ] \
    && pass "an existing directory is refused" \
    || fail "an existing directory is refused"
fi
drop_sandbox

# A worktree resolves info/exclude to the main gitdir.
new_sandbox
write_config ai-rules "$ORIGIN"
git -C "$PROJECT" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$PROJECT" worktree add -q "$SANDBOX/wt" -b wt
cp "$PROJECT/ai-sync.local.json" "$SANDBOX/wt/ai-sync.local.json"
sh "$HERE/ai-sync.sh" -C "$SANDBOX/wt" >/dev/null
actual=$(grep -c '^/\.claude/rules/ai-rules$' "$PROJECT/.git/info/exclude")
check "a worktree writes the main gitdir's exclude" "$actual" "1"
drop_sandbox
