#!/usr/bin/env bats

load helpers

setup()    { setup_repo; }
teardown() { teardown_repo; }

@test "read_toml: basic key in section" {
  cat > agent-md.toml <<EOF
[verify]
typecheck = "npx tsc --noEmit"
EOF
  . .claude/hooks/_lib.sh
  result="$(read_toml agent-md.toml verify typecheck)"
  [ "$result" = "npx tsc --noEmit" ]
}

@test "read_toml: returns empty for missing key" {
  cat > agent-md.toml <<EOF
[verify]
lint = "eslint"
EOF
  . .claude/hooks/_lib.sh
  result="$(read_toml agent-md.toml verify missing)"
  [ -z "$result" ]
}

@test "read_toml: skips other sections" {
  cat > agent-md.toml <<EOF
[other]
typecheck = "wrong"

[verify]
typecheck = "right"
EOF
  . .claude/hooks/_lib.sh
  result="$(read_toml agent-md.toml verify typecheck)"
  [ "$result" = "right" ]
}

@test "read_toml: strips inline comments from values" {
  cat > agent-md.toml <<EOF
[verify]
lint = "eslint"  # inline note
EOF
  . .claude/hooks/_lib.sh
  result="$(read_toml agent-md.toml verify lint)"
  [ "$result" = "eslint" ]
}

@test "read_toml: handles unquoted bools and numbers" {
  cat > agent-md.toml <<EOF
[visual]
required = true
freshness_seconds = 3600
EOF
  . .claude/hooks/_lib.sh
  [ "$(read_toml agent-md.toml visual required)" = "true" ]
  [ "$(read_toml agent-md.toml visual freshness_seconds)" = "3600" ]
}

@test "read_toml: no file, no output, no error" {
  . .claude/hooks/_lib.sh
  result="$(read_toml nonexistent.toml verify lint)"
  [ -z "$result" ]
}
