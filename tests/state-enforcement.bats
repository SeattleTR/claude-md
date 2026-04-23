#!/usr/bin/env bats

load helpers

setup() {
  setup_repo
  mkdir -p memory
  echo "# progress" > memory/progress.md
  # Commit the initial progress.md so it's TRACKED. Otherwise it would
  # itself show up as an untracked "change" and mask the tests.
  git add memory/progress.md
  git commit -q -m "init progress"
}
teardown() { teardown_repo; }

@test "noop: no memory/progress.md" {
  rm memory/progress.md
  out=$(run_hook state-enforcement.sh '{"stop_hook_active":false}')
  [ -z "$out" ]
}

@test "noop: no source files changed" {
  echo "export const x = 1" > src.ts
  git add -A && git commit -q -m init
  out=$(run_hook state-enforcement.sh '{"stop_hook_active":false}')
  [ -z "$out" ]
}

@test "blocks: tracked source modified without progress update" {
  echo "export const x = 1" > src.ts
  git add -A && git commit -q -m init
  echo "export const y = 2" >> src.ts
  out=$(run_hook state-enforcement.sh '{"stop_hook_active":false}')
  echo "$out" | jq -e '.decision == "block"' > /dev/null
}

@test "blocks: untracked source file counts as a change" {
  echo "export const x = 1" > src.ts
  out=$(run_hook state-enforcement.sh '{"stop_hook_active":false}')
  echo "$out" | jq -e '.decision == "block"' > /dev/null
}

@test "passes: source modified AND progress.md updated" {
  echo "export const x = 1" > src.ts
  git add -A && git commit -q -m init
  echo "export const y = 2" >> src.ts
  echo "- done" >> memory/progress.md
  out=$(run_hook state-enforcement.sh '{"stop_hook_active":false}')
  [ -z "$out" ]
}

@test "honors stop_hook_active" {
  echo "export const x = 1" > src.ts
  out=$(run_hook state-enforcement.sh '{"stop_hook_active":true}')
  [ -z "$out" ]
}

@test "ignores markdown-only changes" {
  echo "# doc" > NOTES.md
  out=$(run_hook state-enforcement.sh '{"stop_hook_active":false}')
  [ -z "$out" ]
}
