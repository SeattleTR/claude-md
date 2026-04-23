#!/usr/bin/env bats

load helpers

setup()    { setup_repo; }
teardown() { teardown_repo; }

@test "warns on 'Output too large' marker" {
  input='{"tool_name":"Grep","tool_response":"Output too large — truncated to preview"}'
  out=$(run_hook truncation-check.sh "$input")
  echo "$out" | jq -e '.hookSpecificOutput.additionalContext' > /dev/null
}

@test "silent on normal grep output" {
  input='{"tool_name":"Grep","tool_response":"file1.ts\nfile2.ts"}'
  out=$(run_hook truncation-check.sh "$input")
  [ -z "$out" ]
}

@test "silent on zero-result grep (no bogus low-count warning)" {
  input='{"tool_name":"Grep","tool_response":"","tool_input":{"pattern":"neverMatchesAnything"}}'
  out=$(run_hook truncation-check.sh "$input")
  [ -z "$out" ]
}

@test "silent on small-result grep (no bogus low-count warning)" {
  input='{"tool_name":"Grep","tool_response":"a.ts\nb.ts","tool_input":{"pattern":"x"}}'
  out=$(run_hook truncation-check.sh "$input")
  [ -z "$out" ]
}
