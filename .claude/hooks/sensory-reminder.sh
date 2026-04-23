#!/bin/bash
# sensory-reminder.sh
# Stop hook: if UI files changed, inject a reminder telling the agent to
# perform visual validation before finishing. This is an ADVISORY nudge,
# not enforcement — it does not run Playwright or a VLM, and it does not
# block Stop. Phase 2 adds an artifact-based version that actually blocks.
#
# Renamed from sensory-validation.sh: the old name overclaimed. Nothing
# in this script validates anything.

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

MSG="UI files changed (${UI_CHANGED}). Before marking complete: (1) build and render the change, (2) capture a screenshot (see ./skills/playwright-capture.sh), (3) have it reviewed by a VLM sub-agent or the human. State the visual verification you performed. Do not self-grade."
jq -n --arg m "$MSG" '{hookSpecificOutput: {hookEventName: "Stop", additionalContext: $m}}'
exit 0
