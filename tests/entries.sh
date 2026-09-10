# Parsing ai-sync.local.json.
new_sandbox
write_config ai-rules "$ORIGIN"
actual=$(AI_SYNC_LIB=1 . "$HERE/ai-sync.sh"; read_entries "$PROJECT/ai-sync.local.json")
check "one entry is parsed" "$actual" "ai-rules $ORIGIN"
drop_sandbox

# A file that is not in canonical form is refused, not parsed optimistically.
new_sandbox
printf '{"claude":{"rules":{"ai-rules":"%s"}}}\n' "$ORIGIN" > "$PROJECT/ai-sync.local.json"
if (AI_SYNC_LIB=1 . "$HERE/ai-sync.sh"; read_entries "$PROJECT/ai-sync.local.json") 2>/dev/null; then
  fail "a single-line config is refused"
else
  pass "a single-line config is refused"
fi
drop_sandbox
