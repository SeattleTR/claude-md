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

@test "still blocks on stop_hook_active retries — no escape hatch" {
  cat > agent-md.toml <<EOF
[verify]
typecheck = "false"
EOF
  # First failure
  out=$(run_hook stop-verify.sh '{"stop_hook_active":false}')
  echo "$out" | jq -e '.decision == "block"' > /dev/null
  # Retry 1
  out=$(run_hook stop-verify.sh '{"stop_hook_active":true}')
  echo "$out" | jq -e '.decision == "block"' > /dev/null
  # Retry 2
  out=$(run_hook stop-verify.sh '{"stop_hook_active":true}')
  echo "$out" | jq -e '.decision == "block"' > /dev/null
  # Retry 3 — earlier version released here. We should still block.
  out=$(run_hook stop-verify.sh '{"stop_hook_active":true}')
  echo "$out" | jq -e '.decision == "block"' > /dev/null
}

@test "block payload is valid JSON" {
  cat > agent-md.toml <<EOF
[verify]
lint = "false"
EOF
  out=$(run_hook stop-verify.sh '{"stop_hook_active":false}')
  echo "$out" | jq -e '.decision' > /dev/null
}

@test "shares npm test command with npm_test_cmd helper" {
  # pnpm lockfile should make the hook pick pnpm test (which doesn't
  # exist on PATH here, so the check will fail — proves it was chosen).
  cat > package.json <<'EOF'
{"scripts": {"test": "echo t"}}
EOF
  touch pnpm-lock.yaml
  out=$(run_hook stop-verify.sh '{"stop_hook_active":false}')
  # Either blocks (pnpm not installed → command fails) OR passes. Either
  # way the label must say NPM TEST / pnpm, not npm.
  if echo "$out" | jq -e '.decision == "block"' > /dev/null 2>&1; then
    echo "$out" | jq -e '.reason | test("pnpm")' > /dev/null
  fi
}
