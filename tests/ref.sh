# "URL#REF" pins an entry to a branch, a tag or a commit.

# Commit $1 as the content of core/PROJECT in the rules repository.
commit_project() {
  printf '%s\n' "$1" > "$SANDBOX/ai-rules/.claude/rules/ai-rules/core/PROJECT"
  git -C "$SANDBOX/ai-rules" add -A
  git -C "$SANDBOX/ai-rules" -c user.email=t@t -c user.name=t commit -qm "$1"
}

# A branch is followed: --update moves the copy to its new head, and the
# default branch moving does not reach it.
new_sandbox
git -C "$SANDBOX/ai-rules" checkout -q -b stable
commit_project stable-1
git -C "$SANDBOX/ai-rules" checkout -q main
commit_project main-1
write_config ai-rules "$ORIGIN#stable"
sh "$HERE/ai-sync.sh" -C "$PROJECT" >/dev/null
actual=$(cat "$PROJECT/.claude/rules/ai-rules/core/PROJECT")
check "a branch ref copies that branch" "$actual" "stable-1"

git -C "$SANDBOX/ai-rules" checkout -q stable
commit_project stable-2
git -C "$SANDBOX/ai-rules" checkout -q main
commit_project main-2
sh "$HERE/ai-sync.sh" -C "$PROJECT" --update >/dev/null
actual=$(cat "$PROJECT/.claude/rules/ai-rules/core/PROJECT")
check "--update follows the branch" "$actual" "stable-2"
drop_sandbox

# A commit is a pin: --update leaves the copy where it was.
new_sandbox
pinned=$(git -C "$SANDBOX/ai-rules" rev-parse HEAD)
commit_project later
write_config ai-rules "$ORIGIN#$pinned"
sh "$HERE/ai-sync.sh" -C "$PROJECT" >/dev/null
actual=$(cat "$PROJECT/.claude/rules/ai-rules/core/PROJECT")
check "a commit ref copies that commit" "$actual" "project"
commit_project even-later
sh "$HERE/ai-sync.sh" -C "$PROJECT" --update >/dev/null
actual=$(cat "$PROJECT/.claude/rules/ai-rules/core/PROJECT")
check "--update keeps a commit pin" "$actual" "project"
drop_sandbox

# An abbreviated hash and a tag resolve too.
new_sandbox
short=$(git -C "$SANDBOX/ai-rules" rev-parse --short HEAD)
git -C "$SANDBOX/ai-rules" tag v1
commit_project later
write_config ai-rules "$ORIGIN#$short"
sh "$HERE/ai-sync.sh" -C "$PROJECT" >/dev/null
actual=$(cat "$PROJECT/.claude/rules/ai-rules/core/PROJECT")
check "an abbreviated commit resolves" "$actual" "project"
drop_sandbox

new_sandbox
git -C "$SANDBOX/ai-rules" tag v1
commit_project later
write_config ai-rules "$ORIGIN#v1"
sh "$HERE/ai-sync.sh" -C "$PROJECT" >/dev/null
actual=$(cat "$PROJECT/.claude/rules/ai-rules/core/PROJECT")
check "a tag resolves" "$actual" "project"
drop_sandbox

# The cache holds one clone per ref, so a ref never moves the clone an
# unpinned entry of the same repository reads from.
new_sandbox
pinned=$(git -C "$SANDBOX/ai-rules" rev-parse HEAD)
commit_project head
cat > "$PROJECT/ai-sync.local.json" <<EOF
{
  "version": 1,
  "claude": {
    "rules": {
      "ai-rules": "$ORIGIN#$pinned"
    }
  }
}
EOF
sh "$HERE/ai-sync.sh" -C "$PROJECT" >/dev/null
write_config ai-rules "$ORIGIN"
sh "$HERE/ai-sync.sh" -C "$PROJECT" --force >/dev/null
actual=$(cat "$PROJECT/.claude/rules/ai-rules/core/PROJECT")
check "a ref does not move the unpinned clone" "$actual" "head"
drop_sandbox

# A ref the repository does not have fails the run and names the ref.
new_sandbox
write_config ai-rules "$ORIGIN#nowhere"
if sh "$HERE/ai-sync.sh" -C "$PROJECT" >/dev/null 2>"$SANDBOX/err"; then
  fail "an unknown ref is refused"
else
  grep -q "nowhere" "$SANDBOX/err" \
    && pass "an unknown ref is refused" \
    || fail "an unknown ref is refused"
fi
# The failed clone is not left behind for the next run to copy from.
if sh "$HERE/ai-sync.sh" -C "$PROJECT" >/dev/null 2>&1; then
  fail "an unknown ref is refused on every run"
else
  pass "an unknown ref is refused on every run"
fi
drop_sandbox
