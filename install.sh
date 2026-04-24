#!/bin/bash
# install.sh — agent-md installer
#
# Usage:
#   ./install.sh                                    # current dir, auto-detect agents
#   ./install.sh /path/to/project                   # specific target, all agents
#   ./install.sh --agent=claude /path/to/project    # Claude Code only
#   ./install.sh --agent=codex,cursor .             # multiple specific
#   ./install.sh --no-githooks /path/to/project     # skip git-hooks fallback
#   ./install.sh --dry-run .                        # show what would change
#   ./install.sh --no-overwrite .                   # never replace existing files
#   ./install.sh --claude-settings=skip .           # default: don't touch existing .claude/settings.json
#   ./install.sh --claude-settings=replace .        # back up + overwrite
#   ./install.sh --claude-settings=merge .          # merge hook entries into existing settings.json (jq)
#
# Or via curl (from inside your project dir):
#   curl -sL https://raw.githubusercontent.com/iamfakeguru/agent-md/main/install.sh | bash
#
# Agents supported: claude, codex, cursor, windsurf, all (default)
#
# Defaults (safe by design):
#   --agent=all
#   --no-overwrite OFF — we WILL replace AGENT.md etc., but always back
#     up the old copy to *.bak first.
#   --claude-settings=skip — existing .claude/settings.json is left
#     alone. Users with handcrafted hook wiring don't get clobbered.
#     Pass --claude-settings=merge to splice our hooks in, or
#     --claude-settings=replace to back up and overwrite.
#   memory/ files are never overwritten (user state).
#   .githooks/pre-commit is installed but NOT activated on curl|bash.
#     You get a printed command to activate it manually.
#   .agent/ is auto-added to .gitignore (hook scratch + visual evidence).

set -e

AGENT="all"
TARGET=""
GITHOOKS="ask"
DRY_RUN=0
NO_OVERWRITE=0
CLAUDE_SETTINGS="skip"

for ARG in "$@"; do
  case $ARG in
    --agent=*)     AGENT="${ARG#*=}" ;;
    --githooks)    GITHOOKS="yes" ;;
    --no-githooks) GITHOOKS="no" ;;
    --dry-run)     DRY_RUN=1 ;;
    --no-overwrite) NO_OVERWRITE=1 ;;
    --claude-settings=*) CLAUDE_SETTINGS="${ARG#*=}" ;;
    --help|-h)
      sed -n '2,30p' "$0"; exit 0 ;;
    *)
      [ -z "$TARGET" ] && TARGET="$ARG"
      ;;
  esac
done

case "$CLAUDE_SETTINGS" in
  skip|replace|merge) ;;
  *) echo "Error: --claude-settings must be skip|replace|merge (got '$CLAUDE_SETTINGS')"; exit 1 ;;
esac

TARGET="${TARGET:-.}"

if [ ! -d "$TARGET" ]; then
  echo "Error: target directory does not exist: $TARGET"; exit 1
fi

# Validate agent list early (don't silently skip unknown names)
VALID_AGENTS="claude codex cursor windsurf all auto"
for A in $(echo "$AGENT" | tr ',' ' '); do
  if ! echo " $VALID_AGENTS " | grep -q " $A "; then
    echo "Error: unknown agent '$A'. Valid: $VALID_AGENTS"; exit 1
  fi
done

# Locate source
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)"

if [ ! -f "$SCRIPT_DIR/AGENT.md" ]; then
  # Running via curl pipe — download the package
  echo "▸ Downloading agent-md..."
  TMP=$(mktemp -d)
  curl -sL https://github.com/iamfakeguru/agent-md/archive/main.tar.gz | tar -xz -C "$TMP"
  if [ -d "$TMP/agent-md-main" ]; then
    SCRIPT_DIR="$TMP/agent-md-main"
  fi
fi

if [ ! -f "$SCRIPT_DIR/AGENT.md" ]; then
  echo "Error: cannot locate AGENT.md in $SCRIPT_DIR"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "  ! jq not found. Hooks require jq for JSON parsing; install jq before relying on enforcement."
fi

# Detect curl|bash (stdin not a tty). We use this to keep defaults safe.
NON_INTERACTIVE=0
[ ! -t 0 ] && NON_INTERACTIVE=1

# Resolve which agents to install for
if [ "$AGENT" = "all" ] || [ "$AGENT" = "auto" ]; then
  AGENT_LIST="claude codex cursor windsurf"
else
  AGENT_LIST=$(echo "$AGENT" | tr ',' ' ')
fi

echo "▸ Installing agent-md directives → $TARGET"
echo "▸ Target agents: $AGENT_LIST"
[ "$DRY_RUN" -eq 1 ] && echo "▸ DRY RUN — no files will be changed"
echo ""

# --- Helpers ---
skip_existing() {
  # Return 0 if we should SKIP (file exists and --no-overwrite)
  if [ "$NO_OVERWRITE" -eq 1 ] && [ -e "$1" ]; then
    echo "  · skip (exists)    $(basename "$1")"
    return 0
  fi
  return 1
}

backup_if_exists() {
  [ "$DRY_RUN" -eq 1 ] && return 0
  if [ -f "$1" ] && [ ! -L "$1" ]; then
    # Avoid clobbering an existing *.bak
    local BAK="$1.bak"
    local N=1
    while [ -f "$BAK" ]; do BAK="$1.bak.$N"; N=$((N + 1)); done
    mv "$1" "$BAK"
    echo "  ! backed up $(basename "$1") → $(basename "$BAK")"
  fi
}

copy_file() {
  # src, dst, label
  local src="$1" dst="$2" label="$3"
  skip_existing "$dst" && return 0
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  → would write     $label"
    return 0
  fi
  backup_if_exists "$dst"
  cp "$src" "$dst"
  echo "  ✓ $label"
}

copy_with_agent_body() {
  # dst, label, header
  local dst="$1" label="$2" header="$3"
  skip_existing "$dst" && return 0
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  → would write     $label"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  backup_if_exists "$dst"
  {
    printf '%s\n\n' "$header"
    cat "$SCRIPT_DIR/AGENT.md"
  } > "$dst"
  echo "  ✓ $label"
}

# --- Master file ---
copy_file "$SCRIPT_DIR/AGENT.md" "$TARGET/AGENT.md" "AGENT.md"

# --- Agent-specific instruction files ---
if echo " $AGENT_LIST " | grep -qE " (codex|cursor|windsurf) "; then
  copy_file "$SCRIPT_DIR/AGENT.md" "$TARGET/AGENTS.md" "AGENTS.md        (Codex / Cursor / Windsurf)"
fi

for TOOL in $AGENT_LIST; do
  case "$TOOL" in
    claude)
      copy_file "$SCRIPT_DIR/AGENT.md" "$TARGET/CLAUDE.md" "CLAUDE.md        (Claude Code)"
      ;;
    codex)
      if [ "$DRY_RUN" -eq 0 ]; then
        mkdir -p "$TARGET/.codex/hooks" "$TARGET/.agents/skills"
      fi
      copy_file "$SCRIPT_DIR/.codex/hooks.json" "$TARGET/.codex/hooks.json" ".codex/hooks.json"
      for H in "$SCRIPT_DIR/.codex/hooks/"*.sh; do
        [ -f "$H" ] || continue
        copy_file "$H" "$TARGET/.codex/hooks/$(basename "$H")" ".codex/hooks/$(basename "$H")"
      done
      if [ "$DRY_RUN" -eq 0 ]; then
        chmod +x "$TARGET/.codex/hooks/"*.sh 2>/dev/null || true
      fi
      for S in "$SCRIPT_DIR/.agents/skills/"*; do
        [ -d "$S" ] || continue
        SKILL_NAME=$(basename "$S")
        [ "$DRY_RUN" -eq 0 ] && mkdir -p "$TARGET/.agents/skills/$SKILL_NAME"
        for F in "$S"/*; do
          [ -f "$F" ] || continue
          copy_file "$F" "$TARGET/.agents/skills/$SKILL_NAME/$(basename "$F")" ".agents/skills/$SKILL_NAME/$(basename "$F")"
        done
      done
      ;;
    cursor)
      copy_with_agent_body "$TARGET/.cursor/rules/agent-md.mdc" ".cursor/rules/agent-md.mdc (Cursor)" "---"$'\n'"alwaysApply: true"$'\n'"---"
      ;;
    windsurf)
      copy_with_agent_body "$TARGET/.windsurf/rules/agent-md.md" ".windsurf/rules/agent-md.md (Windsurf)" "---"$'\n'"trigger: always_on"$'\n'"---"
      ;;
  esac
done

# --- Claude Code hooks ---
if echo " $AGENT_LIST " | grep -q " claude "; then
  [ "$DRY_RUN" -eq 0 ] && mkdir -p "$TARGET/.claude/hooks"

  # settings.json handling is explicit — people hand-wire hooks and we
  # must not silently clobber them. Default is skip.
  SETTINGS_SRC="$SCRIPT_DIR/.claude/settings.json"
  SETTINGS_DST="$TARGET/.claude/settings.json"
  if [ -f "$SETTINGS_SRC" ]; then
    if [ ! -f "$SETTINGS_DST" ]; then
      # No existing settings — always copy.
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "  → would write     .claude/settings.json"
      else
        cp "$SETTINGS_SRC" "$SETTINGS_DST"
        echo "  ✓ .claude/settings.json"
      fi
    else
      case "$CLAUDE_SETTINGS" in
        skip)
          echo "  · .claude/settings.json exists — not touched (--claude-settings=merge|replace to change)"
          ;;
        replace)
          if [ "$DRY_RUN" -eq 1 ]; then
            echo "  → would back up + replace .claude/settings.json"
          else
            backup_if_exists "$SETTINGS_DST"
            cp "$SETTINGS_SRC" "$SETTINGS_DST"
            echo "  ✓ .claude/settings.json (replaced, backup kept)"
          fi
          ;;
        merge)
          if ! command -v jq &>/dev/null; then
            echo "  ! jq required for --claude-settings=merge — skipping settings.json"
          elif [ "$DRY_RUN" -eq 1 ]; then
            echo "  → would merge     .claude/settings.json (hooks block only)"
          else
            # Capture the original BEFORE backup (which moves the file away).
            TMP_ORIG=$(mktemp)
            cp "$SETTINGS_DST" "$TMP_ORIG"
            backup_if_exists "$SETTINGS_DST"
            TMP_MERGED=$(mktemp)
            # Merge semantics:
            #   - top-level keys: union, ours wins on conflict for non-hook keys
            #   - .hooks: for each event (PreToolUse, PostToolUse, Stop, ...)
            #     concatenate user's entries with ours so both fire.
            if jq -s '
              .[0] as $a | .[1] as $b |
              ($a * $b) |
              .hooks = (
                (($a.hooks // {}) | keys) + (($b.hooks // {}) | keys) | unique
                | map(. as $k | {($k): (($a.hooks[$k] // []) + ($b.hooks[$k] // []))})
                | add
              )
            ' "$TMP_ORIG" "$SETTINGS_SRC" > "$TMP_MERGED" 2>/dev/null; then
              mv "$TMP_MERGED" "$SETTINGS_DST"
              echo "  ✓ .claude/settings.json (merged)"
            else
              # Merge failed — restore the original so we don't leave the
              # user with nothing.
              cp "$TMP_ORIG" "$SETTINGS_DST"
              echo "  ! merge failed — restored original from backup"
              rm -f "$TMP_MERGED"
            fi
            rm -f "$TMP_ORIG"
          fi
          ;;
      esac
    fi
  fi

  if [ "$DRY_RUN" -eq 0 ]; then
    for H in "$SCRIPT_DIR/.claude/hooks/"*.sh; do
      [ -f "$H" ] || continue
      copy_file "$H" "$TARGET/.claude/hooks/$(basename "$H")" ".claude/hooks/$(basename "$H")"
    done
    chmod +x "$TARGET/.claude/hooks/"*.sh 2>/dev/null || true
    HOOK_COUNT=$(find "$TARGET/.claude/hooks" -maxdepth 1 -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')
    echo "  ✓ .claude/hooks/   (${HOOK_COUNT} hooks)"
  else
    echo "  → would write     .claude/hooks/*.sh"
  fi
fi

# --- Memory system (never overwrite user's state) ---
if [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p "$TARGET/memory"
  for F in agents.md plan.md progress.md verify.md gotchas.md; do
    if [ ! -f "$TARGET/memory/$F" ] && [ -f "$SCRIPT_DIR/memory/$F" ]; then
      cp "$SCRIPT_DIR/memory/$F" "$TARGET/memory/$F"
    fi
  done
  echo "  ✓ memory/          (5-file state system; existing files preserved)"
else
  echo "  → would populate  memory/ (only missing files)"
fi

# --- agent-md helper scripts ---
if [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p "$TARGET/.agent-md/bin"
  if [ -f "$SCRIPT_DIR/.agent-md/README.md" ]; then
    copy_file "$SCRIPT_DIR/.agent-md/README.md" "$TARGET/.agent-md/README.md" ".agent-md/README.md"
  fi
  for F in "$SCRIPT_DIR/.agent-md/bin/"*; do
    [ -f "$F" ] || continue
    DST="$TARGET/.agent-md/bin/$(basename "$F")"
    copy_file "$F" "$DST" ".agent-md/bin/$(basename "$F")"
  done
  chmod +x "$TARGET/.agent-md/bin/"*.sh 2>/dev/null || true
  echo "  ✓ .agent-md/bin/   (plain helper scripts)"
else
  echo "  → would write     .agent-md/bin/*"
fi

# --- Config template (never overwrite a real agent-md.toml) ---
if [ -f "$SCRIPT_DIR/agent-md.toml.example" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  → would write     agent-md.toml.example"
  elif [ ! -f "$TARGET/agent-md.toml" ]; then
    cp "$SCRIPT_DIR/agent-md.toml.example" "$TARGET/agent-md.toml.example"
    echo "  ✓ agent-md.toml.example  (copy to agent-md.toml to declare verify commands)"
  else
    echo "  · agent-md.toml already present — not touched"
  fi
fi

# --- .gitignore seeding for hook scratch state ---
# Hooks write to .agent/ for scratch state and visual evidence artifacts.
# None of that is source — keep it out of commits.
if [ "$DRY_RUN" -eq 0 ]; then
  GI="$TARGET/.gitignore"
  # shellcheck disable=SC2016
  MARKER='# added by agent-md installer'
  if [ ! -f "$GI" ]; then
    printf '%s\n' "$MARKER" > "$GI"
  elif ! grep -qF "$MARKER" "$GI"; then
    printf '\n%s\n' "$MARKER" >> "$GI"
  fi
  if ! grep -q '^\.agent/$' "$GI"; then
    if [ -f "$GI" ]; then
      printf '.agent/\n' >> "$GI"
    else
      printf '%s\n.agent/\n' "$MARKER" > "$GI"
    fi
    echo "  ✓ .gitignore       (added .agent/)"
  fi
fi

# --- Universal git hook fallback ---
IN_GIT=0
if git -C "$TARGET" rev-parse --is-inside-work-tree &>/dev/null; then IN_GIT=1; fi

if [ "$IN_GIT" -eq 1 ]; then
  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$TARGET/.githooks"
    copy_file "$SCRIPT_DIR/.githooks/pre-commit" "$TARGET/.githooks/pre-commit" ".githooks/pre-commit"
    chmod +x "$TARGET/.githooks/pre-commit"
  fi

  if [ "$GITHOOKS" = "ask" ]; then
    if [ "$NON_INTERACTIVE" -eq 1 ]; then
      # Safe default for curl|bash: do NOT auto-activate a pre-commit hook.
      GITHOOKS="no"
    else
      printf "▸ Activate .githooks/pre-commit now (runs on every git commit)? [y/N] "
      read -r REPLY
      REPLY="${REPLY:-N}"
      case "$REPLY" in Y|y|yes|Yes) GITHOOKS="yes" ;; *) GITHOOKS="no" ;; esac
    fi
  fi

  if [ "$GITHOOKS" = "yes" ]; then
    [ "$DRY_RUN" -eq 0 ] && (cd "$TARGET" && git config core.hooksPath .githooks)
    echo "  ✓ .githooks/       (active — core.hooksPath=.githooks)"
  else
    echo "  ✓ .githooks/       (installed, NOT active)"
    echo "    → enable with:   git config core.hooksPath .githooks"
  fi
fi

echo ""
if [ "$DRY_RUN" -eq 1 ]; then
  echo "▸ Dry run complete. No files changed."
else
  echo "▸ Installation complete."
fi
echo ""
echo "Next steps:"
echo "  1. Read $TARGET/AGENT.md (the master directives)"
echo "  2. (Optional) cp agent-md.toml.example agent-md.toml and declare your verify commands"
echo "  3. Edit memory/plan.md with your project's design"
echo "  4. Start your agent — it reads directives automatically"
NEXT_STEP=5
if [ "$IN_GIT" -eq 1 ] && [ "$GITHOOKS" = "no" ]; then
  echo "  ${NEXT_STEP}. (Optional) Enable universal hooks: git config core.hooksPath .githooks"
  NEXT_STEP=$((NEXT_STEP + 1))
fi
if echo " $AGENT_LIST " | grep -q " codex "; then
  echo "  ${NEXT_STEP}. (Codex) Enable hooks in ~/.codex/config.toml:"
  echo "       [features]"
  echo "       codex_hooks = true"
fi
