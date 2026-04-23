#!/usr/bin/env bats

load helpers

setup()    { setup_repo; }
teardown() { teardown_repo; }

@test "noop for non-code files" {
  out=$(run_hook post-edit-verify.sh '{"tool_input":{"file_path":"README.md"}}')
  [ -z "$out" ]
}

@test "noop when no file_path provided" {
  out=$(run_hook post-edit-verify.sh '{"tool_input":{}}')
  [ -z "$out" ]
}

@test "passes with lint_file=true config" {
  cat > agent-md.toml <<EOF
[verify]
lint_file = "true"
EOF
  touch src.ts
  out=$(run_hook post-edit-verify.sh '{"tool_input":{"file_path":"src.ts"}}')
  [ -z "$out" ]
}

@test "blocks when lint_file fails" {
  cat > agent-md.toml <<EOF
[verify]
lint_file = "false"
EOF
  touch src.ts
  out=$(run_hook post-edit-verify.sh '{"tool_input":{"file_path":"src.ts"}}')
  echo "$out" | jq -e '.decision == "block"' > /dev/null
}

@test "{file} substitution passes file path to command" {
  cat > agent-md.toml <<EOF
[verify]
lint_file = "test -f {file}"
EOF
  touch src.ts
  out=$(run_hook post-edit-verify.sh '{"tool_input":{"file_path":"src.ts"}}')
  [ -z "$out" ]
}

@test "safely handles file paths with spaces" {
  cat > agent-md.toml <<EOF
[verify]
lint_file = "test -f {file}"
EOF
  touch "with space.ts"
  out=$(run_hook post-edit-verify.sh '{"tool_input":{"file_path":"with space.ts"}}')
  [ -z "$out" ]
}
