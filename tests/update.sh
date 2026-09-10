# --update pulls the cache; a bare run does not.
new_sandbox
write_config ai-rules "$ORIGIN"
sh "$HERE/ai-sync.sh" -C "$PROJECT" >/dev/null

printf 'changed\n' > "$SANDBOX/origin/.claude/rules/ai-rules/core/PROJECT"
git -C "$SANDBOX/origin" add -A
git -C "$SANDBOX/origin" -c user.email=t@t -c user.name=t commit -qm change

actual=$(cat "$PROJECT/.claude/rules/ai-rules/core/PROJECT")
check "a bare run leaves the cache where it was" "$actual" "project"

sh "$HERE/ai-sync.sh" -C "$PROJECT" --update >/dev/null
actual=$(cat "$PROJECT/.claude/rules/ai-rules/core/PROJECT")
check "--update pulls the cache" "$actual" "changed"

# A new directory upstream is linked, not just fetched.
printf 'python\n' > "$SANDBOX/origin/.claude/rules/ai-rules/core/NEW"
git -C "$SANDBOX/origin" add -A
git -C "$SANDBOX/origin" -c user.email=t@t -c user.name=t commit -qm new
sh "$HERE/ai-sync.sh" -C "$PROJECT" --update >/dev/null
actual=$(cat "$PROJECT/.claude/rules/ai-rules/core/NEW")
check "--update re-links after an upstream addition" "$actual" "python"
drop_sandbox
