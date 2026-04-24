# tests/helpers.bash — shared setup for bats suites.

setup_repo() {
  # Creates a scratch git repo in a temp dir, copies .claude/ from the
  # parent repo, cds into it. Stores the path in $REPO_DIR.
  REPO_DIR="$(mktemp -d)"
  export REPO_DIR
  cp -r "$BATS_TEST_DIRNAME/../.claude" "$REPO_DIR/"
  cp -r "$BATS_TEST_DIRNAME/../.codex" "$REPO_DIR/" 2>/dev/null || true
  cd "$REPO_DIR"
  git init -q
  git config user.email t@t
  git config user.name t
}

teardown_repo() {
  # shellcheck disable=SC2164
  cd "$BATS_TEST_DIRNAME"
  rm -rf "$REPO_DIR"
}

# Run a hook with stdin JSON. $1 = hook name, $2 = JSON.
run_hook() {
  local hook="$1" input="$2"
  echo "$input" | bash ".claude/hooks/$hook"
}
