# install.sh seeds a config only when there is none.
new_sandbox
AI_SYNC_REPO="file://$HERE" sh "$HERE/install.sh" -C "$PROJECT" --rules "$ORIGIN" >/dev/null
actual=$(grep -c '"ai-rules"' "$PROJECT/ai-sync.local.json")
check "a missing config is seeded from --rules" "$actual" "1"
[ -L "$PROJECT/.claude/rules/ai-rules" ] \
  && pass "seeding then links" || fail "seeding then links"
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
[ -L "$PROJECT/.claude/rules/ai-rules" ] \
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
