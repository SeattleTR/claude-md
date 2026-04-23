#!/bin/bash
# tdd-check.sh
# PostToolUse soft-warning: flags when new exports/functions were added
# to a non-test file without a matching test file. Warns only — doesn't
# block — because the test-first ordering isn't reliably detectable from
# a single hook invocation.

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty')
[ -z "$FILE_PATH" ] && exit 0

# Skip test files, config, docs, hooks themselves
case "$FILE_PATH" in
  *.test.*|*.spec.*|*__tests__*|*/test/*|*/tests/*) exit 0 ;;
  *.config.*|*/docs/*|*/memory/*|*/.claude/*|*/.githooks/*) exit 0 ;;
  *.md|*.json|*.yml|*.yaml|*.toml) exit 0 ;;
esac

# Only source files we care about
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx|*.py|*.rs|*.go) : ;;
  *) exit 0 ;;
esac

[ -f "$FILE_PATH" ] || exit 0

# Does the diff introduce a new export/function/class?
NEW_EXPORTS=0
if git rev-parse --is-inside-work-tree &>/dev/null; then
  if git diff "$FILE_PATH" 2>/dev/null | grep -qE '^\+[^+].*(export\s+(async\s+)?(function|class|const|let)|^\+\s*def\s+\w+|^\+\s*pub\s+fn|^\+\s*func\s+\w+)'; then
    NEW_EXPORTS=1
  fi
fi

[ "$NEW_EXPORTS" -eq 0 ] && exit 0

# Look for a matching test file
DIR=$(dirname "$FILE_PATH")
BASE=$(basename "$FILE_PATH")
STEM="${BASE%.*}"
EXT="${BASE##*.}"

CANDIDATES=(
  "$DIR/$STEM.test.$EXT"
  "$DIR/$STEM.spec.$EXT"
  "$DIR/__tests__/$STEM.test.$EXT"
  "$DIR/__tests__/$STEM.spec.$EXT"
  "$DIR/../tests/test_$STEM.py"
  "$DIR/../test/test_$STEM.py"
  "$DIR/test_$STEM.py"
)

for C in "${CANDIDATES[@]}"; do
  if [ -f "$C" ]; then
    exit 0  # A test file exists — soft check passes
  fi
done

MSG="TDD check: new export(s) in $FILE_PATH but no matching test file found. Per Red-Green TDD: write the failing test first, then the implementation. If this is refactor-only, note it in memory/progress.md."
echo "{\"additionalContext\": \"${MSG}\"}"
exit 0
