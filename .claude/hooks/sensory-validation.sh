#!/bin/bash
# sensory-validation.sh
# Stop hook: if UI files were modified, require visual validation before
# completion. Self-grading of UI (eyeballing the code) is forbidden.
#
# Tier 1 (preferred): runs playwright-capture + VLM review if available.
# Tier 2 (fallback):  injects a directive demanding explicit visual proof.

INPUT=$(cat)

STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

git rev-parse --is-inside-work-tree &>/dev/null || exit 0

UI_PATTERN='\.(tsx|jsx|vue|svelte|astro|css|scss|sass|html)$'
UI_CHANGED=$(
  { git diff --name-only 2>/dev/null; git diff --cached --name-only 2>/dev/null; } \
    | grep -cE "$UI_PATTERN"
)
UI_CHANGED=${UI_CHANGED:-0}

if [ "$UI_CHANGED" -eq 0 ]; then
  exit 0
fi

# Tier 1: full validation pipeline available?
if [ -x "skills/playwright-capture.sh" ] \
   && ([ -d "node_modules/playwright" ] || [ -d "node_modules/@playwright" ]) \
   && [ -n "$ANTHROPIC_API_KEY" ]; then
  MSG="UI files changed (${UI_CHANGED}). Before completing: run ./skills/playwright-capture.sh <url> to capture a screenshot, then submit it to a VLM for independent review. Do not self-grade visual correctness."
  echo "{\"additionalContext\": \"${MSG}\"}"
  exit 0
fi

# Tier 2: fallback directive
MSG="UI files changed (${UI_CHANGED}). Before marking complete you MUST confirm: (1) the app actually built and rendered, (2) a screenshot was visually inspected (human or VLM sub-agent), (3) no 'it should work' claims based on code structure. State explicitly what visual verification you performed. If you cannot verify visually, halt and ask the human."
echo "{\"additionalContext\": \"${MSG}\"}"
exit 0
