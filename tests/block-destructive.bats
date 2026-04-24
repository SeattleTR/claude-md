#!/usr/bin/env bats

load helpers

setup()    { setup_repo; }
teardown() { teardown_repo; }

@test "allows benign commands" {
  out=$(run_hook block-destructive.sh '{"tool_input":{"command":"ls -la"}}')
  [ -z "$out" ]
}

@test "denies rm -rf /" {
  out=$(run_hook block-destructive.sh '{"tool_input":{"command":"rm -rf /"}}')
  echo "$out" | grep -q '"permissionDecision": "deny"'
}

@test "denies rm -rf ~" {
  out=$(run_hook block-destructive.sh '{"tool_input":{"command":"rm -rf ~/important"}}')
  echo "$out" | grep -q '"permissionDecision": "deny"'
}

@test "denies DROP TABLE" {
  out=$(run_hook block-destructive.sh '{"tool_input":{"command":"psql -c \"DROP TABLE users\""}}')
  echo "$out" | grep -q '"permissionDecision": "deny"'
}

@test "denies git push --force" {
  out=$(run_hook block-destructive.sh '{"tool_input":{"command":"git push --force origin main"}}')
  echo "$out" | grep -q '"permissionDecision": "deny"'
}

@test "denies git push -f" {
  out=$(run_hook block-destructive.sh '{"tool_input":{"command":"git push -f"}}')
  echo "$out" | grep -q '"permissionDecision": "deny"'
}

@test "denies git reset --hard" {
  out=$(run_hook block-destructive.sh '{"tool_input":{"command":"git reset --hard"}}')
  echo "$out" | grep -q '"permissionDecision": "deny"'
}

@test "denies cat .env" {
  out=$(run_hook block-destructive.sh '{"tool_input":{"command":"cat .env"}}')
  echo "$out" | grep -q '"permissionDecision": "deny"'
}

@test "denies cat nested .env" {
  out=$(run_hook block-destructive.sh '{"tool_input":{"command":"cat config/.env"}}')
  echo "$out" | grep -q '"permissionDecision": "deny"'
}

@test "denies grep token from .env" {
  out=$(run_hook block-destructive.sh '{"tool_input":{"command":"grep API_KEY .env"}}')
  echo "$out" | grep -q '"permissionDecision": "deny"'
}

@test "denies find -delete" {
  out=$(run_hook block-destructive.sh '{"tool_input":{"command":"find . -name \"*.log\" -delete"}}')
  echo "$out" | grep -q '"permissionDecision": "deny"'
}

@test "denies git clean -fdx" {
  out=$(run_hook block-destructive.sh '{"tool_input":{"command":"git clean -fdx"}}')
  echo "$out" | grep -q '"permissionDecision": "deny"'
}

@test "allows cat .env.example (not a real env file)" {
  out=$(run_hook block-destructive.sh '{"tool_input":{"command":"cat .env.example"}}')
  [ -z "$out" ]
}

@test "deny payload is valid JSON" {
  out=$(run_hook block-destructive.sh '{"tool_input":{"command":"rm -rf /"}}')
  echo "$out" | jq -e '.hookSpecificOutput.permissionDecision' > /dev/null
}
