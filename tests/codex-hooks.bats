#!/usr/bin/env bats

load helpers

setup()    { setup_repo; }
teardown() { teardown_repo; }

@test "codex PreToolUse wrapper blocks destructive Bash" {
  out=$(echo '{"tool_input":{"command":"git reset --hard"}}' | bash .codex/hooks/pre-tool-use.sh)
  echo "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' > /dev/null
}

@test "codex Stop wrapper emits first blocking verification decision" {
  cat > agent-md.toml <<EOF
[verify]
typecheck = "false"
EOF
  out=$(echo '{"stop_hook_active":false}' | bash .codex/hooks/stop.sh)
  echo "$out" | jq -e '.decision == "block"' > /dev/null
  echo "$out" | jq -e '.reason | test("TYPECHECK")' > /dev/null
}

@test "codex Stop wrapper converts advisory context to systemMessage" {
  out=$(echo '{"stop_hook_active":false}' | bash .codex/hooks/stop.sh)
  echo "$out" | jq -e '.systemMessage | test("unverified")' > /dev/null
}
