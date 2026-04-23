#!/bin/bash
# stop-verify.sh
# Runs when Claude tries to finish a task (Stop event).
# The agent cannot declare "Done!" until the project actually compiles,
# lints, and passes tests.
#
# Hook output contract (Claude Code):
#   exit 0 + JSON on stdout → Claude reads the structured decision.
#   We use {decision:"block", reason:...} on stdout with exit 0.
#
# Infinite-loop guard: `stop_hook_active` is set to true when Claude
# retries after a block. We honor it so retries don't loop forever.
# (Caveat: a retry can pass without actually re-running verification —
# Phase 2 addresses this with a failure-hash strategy.)

INPUT=$(cat)

# Prevent infinite loop: if this hook already blocked once and Claude
# retried, allow the stop
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

ERRORS=""
CHECKS_RUN=0

# --- TypeScript type-check (runs here, not per-edit, to avoid 10-30s delays) ---
if [ -f "tsconfig.json" ]; then
  CHECKS_RUN=$((CHECKS_RUN + 1))
  TSC_OUTPUT=$(npx tsc --noEmit 2>&1)
  if [ $? -ne 0 ]; then
    ERRORS="${ERRORS}TYPE CHECK FAILED:\n$(echo "$TSC_OUTPUT" | head -30)\n\n"
  fi
fi

# --- ESLint (full project) ---
if [ -f ".eslintrc" ] || [ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ] || [ -f ".eslintrc.yml" ] || [ -f "eslint.config.js" ] || [ -f "eslint.config.mjs" ] || [ -f "eslint.config.ts" ]; then
  CHECKS_RUN=$((CHECKS_RUN + 1))
  ESLINT_OUTPUT=$(npx eslint . --quiet 2>&1)
  if [ $? -ne 0 ]; then
    ERRORS="${ERRORS}LINT FAILED:\n$(echo "$ESLINT_OUTPUT" | head -30)\n\n"
  fi
fi

# --- Python type-check ---
if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "setup.cfg" ]; then
  if command -v mypy &> /dev/null && { [ -f "mypy.ini" ] || grep -q '\[tool.mypy\]' pyproject.toml 2>/dev/null; }; then
    CHECKS_RUN=$((CHECKS_RUN + 1))
    MYPY_OUTPUT=$(mypy . 2>&1)
    if [ $? -ne 0 ]; then
      ERRORS="${ERRORS}MYPY FAILED:\n$(echo "$MYPY_OUTPUT" | head -30)\n\n"
    fi
  fi

  if command -v ruff &> /dev/null; then
    CHECKS_RUN=$((CHECKS_RUN + 1))
    RUFF_OUTPUT=$(ruff check . 2>&1)
    if [ $? -ne 0 ]; then
      ERRORS="${ERRORS}RUFF FAILED:\n$(echo "$RUFF_OUTPUT" | head -30)\n\n"
    fi
  fi
fi

# --- Rust ---
if [ -f "Cargo.toml" ]; then
  CHECKS_RUN=$((CHECKS_RUN + 1))
  CARGO_OUTPUT=$(cargo check 2>&1)
  if [ $? -ne 0 ]; then
    ERRORS="${ERRORS}CARGO CHECK FAILED:\n$(echo "$CARGO_OUTPUT" | head -30)\n\n"
  fi
fi

# --- Test suite ---
TEST_RUNNER=""
if [ -f "package.json" ]; then
  HAS_TEST=$(jq -r '.scripts.test // empty' package.json 2>/dev/null)
  if [ -n "$HAS_TEST" ] && [ "$HAS_TEST" != "echo \"Error: no test specified\" && exit 1" ]; then
    TEST_RUNNER="npm test"
  fi
elif [ -f "pytest.ini" ] || [ -f "pyproject.toml" ]; then
  if command -v pytest &> /dev/null; then
    TEST_RUNNER="pytest --tb=short -q"
  fi
elif [ -f "Cargo.toml" ]; then
  TEST_RUNNER="cargo test"
fi

if [ -n "$TEST_RUNNER" ]; then
  CHECKS_RUN=$((CHECKS_RUN + 1))
  TEST_OUTPUT=$(eval "$TEST_RUNNER" 2>&1)
  if [ $? -ne 0 ]; then
    ERRORS="${ERRORS}TESTS FAILED ($TEST_RUNNER):\n$(echo "$TEST_OUTPUT" | tail -30)\n\n"
  fi
fi

# --- Report ---
if [ -n "$ERRORS" ]; then
  SUMMARY=$(printf 'Verification failed (%d checks ran). Fix these errors before completing:\n\n%b' \
    "$CHECKS_RUN" "$ERRORS")
  jq -n --arg r "$SUMMARY" '{decision: "block", reason: $r}'
  exit 0
fi

if [ $CHECKS_RUN -eq 0 ]; then
  jq -n '{hookSpecificOutput: {hookEventName: "Stop", additionalContext: "No type-checker, linter, or test suite detected. Task completion is unverified. State this to the user."}}'
  exit 0
fi

exit 0
