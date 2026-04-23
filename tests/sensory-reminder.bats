#!/usr/bin/env bats

load helpers

setup()    { setup_repo; }
teardown() { teardown_repo; }

@test "silent when no UI files changed" {
  echo "export const x = 1" > src.ts
  git add -A && git commit -q -m init
  out=$(run_hook sensory-reminder.sh '{"stop_hook_active":false}')
  [ -z "$out" ]
}

@test "advisory reminder when UI files changed (default mode)" {
  echo "<div/>" > App.tsx
  out=$(run_hook sensory-reminder.sh '{"stop_hook_active":false}')
  echo "$out" | jq -e '.hookSpecificOutput.additionalContext' > /dev/null
}

@test "blocks when required=true and no artifact exists" {
  cat > agent-md.toml <<EOF
[visual]
required = true
artifacts_dir = ".agent/visual"
freshness_seconds = 3600
EOF
  echo "<div/>" > App.tsx
  out=$(run_hook sensory-reminder.sh '{"stop_hook_active":false}')
  echo "$out" | jq -e '.decision == "block"' > /dev/null
}

@test "passes when required=true and fresh artifact exists" {
  cat > agent-md.toml <<EOF
[visual]
required = true
artifacts_dir = ".agent/visual"
freshness_seconds = 3600
EOF
  echo "<div/>" > App.tsx
  mkdir -p .agent/visual
  touch .agent/visual/home.png
  out=$(run_hook sensory-reminder.sh '{"stop_hook_active":false}')
  # Should emit an advisory, not a block
  echo "$out" | jq -e '.hookSpecificOutput.additionalContext' > /dev/null
  run sh -c "echo '$out' | jq -e '.decision // empty'"
  [ -z "$output" ] || [ "$output" = '""' ]
}

@test "honors stop_hook_active" {
  echo "<div/>" > App.tsx
  out=$(run_hook sensory-reminder.sh '{"stop_hook_active":true}')
  [ -z "$out" ]
}
