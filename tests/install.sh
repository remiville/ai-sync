# install.sh seeds a config only when there is none.
#
# These cases run the *committed* ai-sync.sh, not the working tree: install.sh
# clones $AI_SYNC_REPO into the cache and hands off to what it finds there, so
# `file://$HERE` yields HEAD. They are therefore always one commit behind, and
# must assert only what install.sh itself owns. Asserting the shape of the
# entry here once read `[ -L ]` and went on passing after the entry became a
# directory, because the clone still held the linking script — a green test
# measuring the previous commit. What install.sh promises is the hand-off; that
# the hand-off copies is copy.sh's business.
new_sandbox
AI_SYNC_REPO="file://$HERE" sh "$HERE/install.sh" -C "$PROJECT" --rules "$ORIGIN" >/dev/null
actual=$(grep -c '"ai-rules"' "$PROJECT/ai-sync.local.json")
check "a missing config is seeded from --rules" "$actual" "1"
[ -e "$PROJECT/.claude/rules/ai-rules" ] \
  && pass "seeding then hands off" || fail "seeding then hands off"
drop_sandbox

# No config and no --rules is an error naming the option.
new_sandbox
if AI_SYNC_REPO="file://$HERE" sh "$HERE/install.sh" -C "$PROJECT" >/dev/null 2>&1; then
  fail "no config and no --rules fails"
else
  pass "no config and no --rules fails"
fi
drop_sandbox

# The same URL again is safe: re-running the one-liner must not break.
new_sandbox
write_config ai-rules "$ORIGIN"
AI_SYNC_REPO="file://$HERE" sh "$HERE/install.sh" -C "$PROJECT" --rules "$ORIGIN" >/dev/null
[ -e "$PROJECT/.claude/rules/ai-rules" ] \
  && pass "a matching --rules proceeds" || fail "a matching --rules proceeds"
drop_sandbox

# A different URL is refused rather than overwriting.
new_sandbox
write_config ai-rules "$ORIGIN"
if AI_SYNC_REPO="file://$HERE" sh "$HERE/install.sh" -C "$PROJECT" \
     --rules https://example.invalid/other.git >/dev/null 2>&1; then
  fail "a conflicting --rules is refused"
else
  grep -q "$ORIGIN" "$PROJECT/ai-sync.local.json" \
    && pass "a conflicting --rules is refused" \
    || fail "a conflicting --rules is refused"
fi
drop_sandbox

# install.sh seeds the user config and performs the first copy.
new_sandbox
AI_SYNC_REPO="file://$HERE" sh "$HERE/install.sh" --rules "$ORIGIN" >/dev/null 2>&1 || true
actual=$([ -f "$HOME/.config/ai-sync/ai-sync.local.json" ] && echo yes || echo no)
check "install.sh seeds the user config" "$actual" "yes"
actual=$(cat "$HOME/.claude/rules/ai-rules/core/PROJECT" 2>/dev/null || true)
check "install.sh performs the first copy" "$actual" "project"
drop_sandbox
