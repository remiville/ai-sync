# The default destination is the home, with no argument at all.
new_sandbox
write_user_config ai-rules "$ORIGIN"
sh "$HERE/ai-sync.sh" >/dev/null

actual=$(cat "$HOME/.claude/rules/ai-rules/core/PROJECT")
check "a bare run copies into the home" "$actual" "project"

actual=$([ -e "$PROJECT/.claude" ] && echo yes || echo no)
check "a bare run leaves the project alone" "$actual" "no"
drop_sandbox

# -C is the opt-in, and still copies where it is told.
new_sandbox
write_config ai-rules "$ORIGIN"
sh "$HERE/ai-sync.sh" -C "$PROJECT" >/dev/null

actual=$(cat "$PROJECT/.claude/rules/ai-rules/core/PROJECT")
check "-C copies into the project" "$actual" "project"

actual=$([ -e "$HOME/.claude" ] && echo yes || echo no)
check "-C leaves the home alone" "$actual" "no"
drop_sandbox

# A missing user config is refused, and names the path it looked at.
new_sandbox
if sh "$HERE/ai-sync.sh" >/dev/null 2>"$SANDBOX/err"; then
  fail "a missing user config is refused"
else
  grep -q "$HOME/.config/ai-sync/ai-sync.local.json" "$SANDBOX/err" \
    && pass "a missing user config is refused" \
    || fail "a missing user config is refused"
fi
drop_sandbox

# The home may itself be a git repository — versioned dotfiles are ordinary.
# Nothing is written to its info/exclude either.
new_sandbox
git -C "$HOME" init -q -b main
write_user_config ai-rules "$ORIGIN"
sh "$HERE/ai-sync.sh" >/dev/null
actual=$(grep -c '^/\.claude' "$HOME/.git/info/exclude" || true)
check "a git home keeps its info/exclude" "$actual" "0"
drop_sandbox
