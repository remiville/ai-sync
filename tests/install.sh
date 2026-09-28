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

# A second rules repository beside the first, serving entry $1.
new_rules_repo() {
  mkdir -p "$SANDBOX/$1/.claude/rules/$1"
  printf '%s\n' "$1" > "$SANDBOX/$1/.claude/rules/$1/README"
  git -C "$SANDBOX/$1" init -q -b main
  git -C "$SANDBOX/$1" add -A
  git -C "$SANDBOX/$1" -c user.email=t@t -c user.name=t commit -qm init
}

# A repository the config does not name yet is added beside what it holds:
# a machine gains a second rules repository with the same one-liner.
new_sandbox
new_rules_repo timesheet
write_config ai-rules "$ORIGIN"
AI_SYNC_REPO="file://$HERE" sh "$HERE/install.sh" -C "$PROJECT" \
  --rules "file://$SANDBOX/timesheet" >/dev/null || true
actual=$(grep -c -e "\"ai-rules\": \"$ORIGIN\"" \
  -e "\"timesheet\": \"file://$SANDBOX/timesheet\"" "$PROJECT/ai-sync.local.json")
check "a new --rules is added beside the existing entry" "$actual" "2"
actual=$(cat "$PROJECT/.claude/rules/timesheet/README" 2>/dev/null || true)
check "the added entry is copied" "$actual" "timesheet"
[ -e "$PROJECT/.claude/rules/ai-rules" ] \
  && pass "the existing entry is still copied" \
  || fail "the existing entry is still copied"
drop_sandbox

# Re-running the installer is asking for the current directives, so a copy
# already in place is refreshed rather than asked about: a refusal there would
# stop the hand-off before the entries after it are copied.
new_sandbox
new_rules_repo timesheet
write_config ai-rules "$ORIGIN"
mkdir -p "$PROJECT/.claude/rules/ai-rules"
printf 'stale\n' > "$PROJECT/.claude/rules/ai-rules/STALE"
AI_SYNC_REPO="file://$HERE" sh "$HERE/install.sh" -C "$PROJECT" \
  --rules "file://$SANDBOX/timesheet" </dev/null >/dev/null 2>&1 || true
actual=$([ -e "$PROJECT/.claude/rules/ai-rules/STALE" ] && echo kept || echo replaced)
check "an existing copy is refreshed" "$actual" "replaced"
actual=$(cat "$PROJECT/.claude/rules/timesheet/README" 2>/dev/null || true)
check "an existing copy does not block the added entry" "$actual" "timesheet"
drop_sandbox

# --entry names the added entry.
new_sandbox
new_rules_repo timesheet
write_config ai-rules "$ORIGIN"
AI_SYNC_REPO="file://$HERE" sh "$HERE/install.sh" -C "$PROJECT" \
  --rules "file://$SANDBOX/timesheet" --entry ts >/dev/null 2>&1 || true
actual=$(grep -c "\"ts\": \"file://$SANDBOX/timesheet\"" "$PROJECT/ai-sync.local.json")
check "--entry names the added entry" "$actual" "1"
drop_sandbox

# An entry name the config already holds, under another URL, is refused rather
# than overwritten: that is a replacement, and the user edits it.
new_sandbox
write_config ai-rules "$ORIGIN"
before=$(cat "$PROJECT/ai-sync.local.json")
if AI_SYNC_REPO="file://$HERE" sh "$HERE/install.sh" -C "$PROJECT" \
     --rules https://example.invalid/ai-rules.git >/dev/null 2>&1; then
  fail "a conflicting entry name is refused"
else
  check "a conflicting entry name is refused" \
    "$(cat "$PROJECT/ai-sync.local.json")" "$before"
fi
drop_sandbox

# A config the template would not produce is not rewritten: regenerating it
# would drop whatever the user put there.
new_sandbox
new_rules_repo timesheet
printf '{"version": 1, "claude": {"rules": {"ai-rules": "%s"}}}\n' "$ORIGIN" \
  > "$PROJECT/ai-sync.local.json"
before=$(cat "$PROJECT/ai-sync.local.json")
if AI_SYNC_REPO="file://$HERE" sh "$HERE/install.sh" -C "$PROJECT" \
     --rules "file://$SANDBOX/timesheet" >/dev/null 2>&1; then
  fail "a non-canonical config is not rewritten"
else
  check "a non-canonical config is not rewritten" \
    "$(cat "$PROJECT/ai-sync.local.json")" "$before"
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

# A ref after '#' is stored with the URL, where --update reads it, and is not
# part of the entry name.
new_sandbox
AI_SYNC_REPO="file://$HERE" sh "$HERE/install.sh" -C "$PROJECT" \
  --rules "$ORIGIN#main" >/dev/null 2>&1 || true
actual=$(grep -c "\"ai-rules\": \"$ORIGIN#main\"" "$PROJECT/ai-sync.local.json" || true)
check "a ref is stored with the URL" "$actual" "1"
drop_sandbox

# The same repository at another ref, under the same name, is a replacement
# and is refused like any other.
new_sandbox
write_config ai-rules "$ORIGIN#main"
before=$(cat "$PROJECT/ai-sync.local.json")
if AI_SYNC_REPO="file://$HERE" sh "$HERE/install.sh" -C "$PROJECT" \
     --rules "$ORIGIN#stable" >/dev/null 2>&1; then
  fail "another ref under the same name is refused"
else
  check "another ref under the same name is refused" \
    "$(cat "$PROJECT/ai-sync.local.json")" "$before"
fi
drop_sandbox
