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

# read_entries is tested above in isolation, where it refuses correctly. These
# three run the *script*, which is where the refusal has to arrive: a caller
# that cannot see a failure is a caller that reports success. The gap between
# the two is what let claude-bot's --update-rules print "ok" for fourteen
# projects that had no config at all and therefore no directives.
for case in missing malformed empty; do
  new_sandbox
  case $case in
    missing) : ;;
    malformed) printf '{"hello": "world"}\n' > "$PROJECT/ai-sync.local.json" ;;
    empty) printf '{\n  "version": 1,\n  "claude": {\n    "rules": {\n    }\n  }\n}\n' \
      > "$PROJECT/ai-sync.local.json" ;;
  esac
  if sh "$HERE/ai-sync.sh" -C "$PROJECT" >/dev/null 2>&1; then
    fail "a $case config makes the script exit non-zero"
  else
    pass "a $case config makes the script exit non-zero"
  fi
  drop_sandbox
done
