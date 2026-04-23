#!/usr/bin/env bats

load helpers

setup()    { setup_repo; }
teardown() { teardown_repo; }

@test "passes when all configured checks pass" {
  cat > agent-md.toml <<EOF
[verify]
typecheck = "true"
lint = "true"
test = "true"
EOF
  out=$(run_hook stop-verify.sh '{"stop_hook_active":false}')
  [ -z "$out" ]
}

@test "blocks when a check fails" {
  cat > agent-md.toml <<EOF
[verify]
typecheck = "true"
lint = "false"
test = "true"
EOF
  out=$(run_hook stop-verify.sh '{"stop_hook_active":false}')
  echo "$out" | jq -e '.decision == "block"' > /dev/null
  echo "$out" | jq -e '.reason | test("LINT")' > /dev/null
}

@test "advisory when no checks configured and no heuristic matches" {
  out=$(run_hook stop-verify.sh '{"stop_hook_active":false}')
  echo "$out" | jq -e '.hookSpecificOutput.additionalContext | test("not.*verif|unverified"; "i")' > /dev/null
}

@test "retry counter breaks out after 3 consecutive failures" {
  cat > agent-md.toml <<EOF
[verify]
typecheck = "false"
EOF
  run_hook stop-verify.sh '{"stop_hook_active":false}' > /dev/null
  run_hook stop-verify.sh '{"stop_hook_active":true}'  > /dev/null
  out=$(run_hook stop-verify.sh '{"stop_hook_active":true}')
  # On the 3rd failing retry, we release the Stop with an advisory
  echo "$out" | jq -e '.hookSpecificOutput.additionalContext' > /dev/null
}

@test "retry counter resets on clean pass" {
  cat > agent-md.toml <<EOF
[verify]
typecheck = "false"
EOF
  run_hook stop-verify.sh '{"stop_hook_active":false}' > /dev/null
  [ -f ".agent/state/stop-verify-retries" ]
  # Flip to passing config
  cat > agent-md.toml <<EOF
[verify]
typecheck = "true"
EOF
  run_hook stop-verify.sh '{"stop_hook_active":true}' > /dev/null
  [ ! -f ".agent/state/stop-verify-retries" ]
}

@test "block payload is valid JSON" {
  cat > agent-md.toml <<EOF
[verify]
lint = "false"
EOF
  out=$(run_hook stop-verify.sh '{"stop_hook_active":false}')
  echo "$out" | jq -e '.decision' > /dev/null
}
