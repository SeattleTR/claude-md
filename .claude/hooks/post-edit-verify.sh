#!/bin/bash
# post-edit-verify.sh
# Runs after every Write/Edit/MultiEdit. Surfaces lint failures so the
# agent sees them immediately. Type-checking runs only at Stop (via
# stop-verify.sh) to avoid 10-30s tsc delays on every single edit.
#
# Hook output contract (Claude Code):
#   exit 0 + JSON on stdout  → Claude reads the structured decision.
#   exit 2 + text on stderr  → Claude reads the stderr.
# We pick ONE — exit 0 with JSON — so the JSON isn't silently discarded.
#
# Note: this is a PostToolUse hook, so the edit already landed on disk.
# The "block" decision here stops Claude from progressing until the
# lint errors are addressed; it does not unwind the write.

INPUT=$(cat)

# Extract the file path from the tool event
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0  # No file path found, skip
fi

# Only check code files
if ! echo "$FILE_PATH" | grep -qE '\.(ts|tsx|js|jsx|py|rs)$'; then
  exit 0
fi

ERRORS=""

# --- TypeScript / JavaScript projects ---
if echo "$FILE_PATH" | grep -qE '\.(ts|tsx|js|jsx)$'; then

  # Run eslint on the specific file (fast, per-file)
  if [ -f ".eslintrc" ] || [ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ] || [ -f ".eslintrc.yml" ] || [ -f "eslint.config.js" ] || [ -f "eslint.config.mjs" ] || [ -f "eslint.config.ts" ]; then
    ESLINT_OUTPUT=$(npx eslint --quiet "$FILE_PATH" 2>&1)
    ESLINT_EXIT=$?
    if [ $ESLINT_EXIT -ne 0 ]; then
      ERRORS="${ERRORS}eslint errors in ${FILE_PATH}:\n${ESLINT_OUTPUT}\n\n"
    fi
  fi
fi

# --- Python projects ---
if echo "$FILE_PATH" | grep -qE '\.py$'; then
  # Run ruff on the specific file (fast, per-file)
  if command -v ruff &> /dev/null; then
    RUFF_OUTPUT=$(ruff check "$FILE_PATH" 2>&1)
    RUFF_EXIT=$?
    if [ $RUFF_EXIT -ne 0 ]; then
      ERRORS="${ERRORS}ruff errors in ${FILE_PATH}:\n${RUFF_OUTPUT}\n\n"
    fi
  fi
fi

# If errors found, emit a block decision as valid JSON (jq handles escaping)
if [ -n "$ERRORS" ]; then
  TRUNCATED=$(printf '%b' "$ERRORS" | head -50)
  REASON="Lint failed. Fix before continuing:
${TRUNCATED}"
  jq -n --arg r "$REASON" '{decision: "block", reason: $r}'
  exit 0
fi

exit 0
