# --update pulls the cache; a bare run does not.
new_sandbox
write_config ai-rules "$ORIGIN"
sh "$HERE/ai-sync.sh" -C "$PROJECT" >/dev/null

printf 'changed\n' > "$SANDBOX/ai-rules/.claude/rules/ai-rules/core/PROJECT"
git -C "$SANDBOX/ai-rules" add -A
git -C "$SANDBOX/ai-rules" -c user.email=t@t -c user.name=t commit -qm change

actual=$(cat "$PROJECT/.claude/rules/ai-rules/core/PROJECT")
check "a bare run leaves the cache where it was" "$actual" "project"

sh "$HERE/ai-sync.sh" -C "$PROJECT" --update >/dev/null
actual=$(cat "$PROJECT/.claude/rules/ai-rules/core/PROJECT")
check "--update pulls the cache" "$actual" "changed"

# A new directory upstream is copied, not just fetched.
printf 'python\n' > "$SANDBOX/ai-rules/.claude/rules/ai-rules/core/NEW"
git -C "$SANDBOX/ai-rules" add -A
git -C "$SANDBOX/ai-rules" -c user.email=t@t -c user.name=t commit -qm new
sh "$HERE/ai-sync.sh" -C "$PROJECT" --update >/dev/null
actual=$(cat "$PROJECT/.claude/rules/ai-rules/core/NEW")
check "--update re-copies after an upstream addition" "$actual" "python"

# A file deleted upstream disappears from the copy. Nothing else catches a
# refresh that copies over the old tree instead of replacing it.
printf 'gone\n' > "$SANDBOX/ai-rules/.claude/rules/ai-rules/core/DOOMED"
git -C "$SANDBOX/ai-rules" add -A
git -C "$SANDBOX/ai-rules" -c user.email=t@t -c user.name=t commit -qm add
sh "$HERE/ai-sync.sh" -C "$PROJECT" --update >/dev/null
[ -f "$PROJECT/.claude/rules/ai-rules/core/DOOMED" ] \
  && pass "the copy gains an upstream file" \
  || fail "the copy gains an upstream file"

git -C "$SANDBOX/ai-rules" rm -q .claude/rules/ai-rules/core/DOOMED
git -C "$SANDBOX/ai-rules" -c user.email=t@t -c user.name=t commit -qm remove
sh "$HERE/ai-sync.sh" -C "$PROJECT" --update >/dev/null
[ -f "$PROJECT/.claude/rules/ai-rules/core/DOOMED" ] \
  && fail "a file deleted upstream disappears from the copy" \
  || pass "a file deleted upstream disappears from the copy"
drop_sandbox
