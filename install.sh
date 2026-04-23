#!/bin/bash
# install.sh — Archimedes Agent Directives installer
#
# Usage:
#   ./install.sh                                    # current dir, auto-detect agents
#   ./install.sh /path/to/project                   # specific target, all agents
#   ./install.sh --agent=claude /path/to/project    # Claude Code only
#   ./install.sh --agent=codex,cursor .             # multiple specific
#   ./install.sh --no-githooks /path/to/project     # skip git-hooks fallback
#   ./install.sh --dry-run .                        # show what would change
#   ./install.sh --no-overwrite .                   # never replace existing files
#
# Or via curl (from inside your project dir):
#   curl -sL https://raw.githubusercontent.com/iamfakeguru/agent-md/main/install.sh | bash
#
# Agents supported: claude, codex, cursor, windsurf, aider, all (default)
#
# Defaults (safe by design):
#   --agent=all
#   --no-overwrite OFF — we WILL replace AGENT.md etc., but always back
#     up the old copy to *.bak first.
#   memory/ files are never overwritten (user state).
#   .githooks/pre-commit is installed but NOT activated on curl|bash.
#     You get a printed command to activate it manually.

set -e

AGENT="all"
TARGET=""
GITHOOKS="ask"
DRY_RUN=0
NO_OVERWRITE=0

for ARG in "$@"; do
  case $ARG in
    --agent=*)     AGENT="${ARG#*=}" ;;
    --githooks)    GITHOOKS="yes" ;;
    --no-githooks) GITHOOKS="no" ;;
    --dry-run)     DRY_RUN=1 ;;
    --no-overwrite) NO_OVERWRITE=1 ;;
    --help|-h)
      sed -n '2,25p' "$0"; exit 0 ;;
    *)
      [ -z "$TARGET" ] && TARGET="$ARG"
      ;;
  esac
done

TARGET="${TARGET:-.}"

if [ ! -d "$TARGET" ]; then
  echo "Error: target directory does not exist: $TARGET"; exit 1
fi

# Validate agent list early (don't silently skip unknown names)
VALID_AGENTS="claude codex cursor windsurf aider all auto"
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
  if ! curl -sL https://github.com/iamfakeguru/agent-md/archive/main.tar.gz | tar -xz -C "$TMP"; then
    # Fallback to legacy claude-md URL (GitHub auto-redirects)
    curl -sL https://github.com/iamfakeguru/claude-md/archive/main.tar.gz | tar -xz -C "$TMP"
  fi
  if [ -d "$TMP/agent-md-main" ]; then
    SCRIPT_DIR="$TMP/agent-md-main"
  elif [ -d "$TMP/claude-md-main" ]; then
    SCRIPT_DIR="$TMP/claude-md-main"
  fi
fi

if [ ! -f "$SCRIPT_DIR/AGENT.md" ]; then
  echo "Error: cannot locate AGENT.md in $SCRIPT_DIR"
  exit 1
fi

# Detect curl|bash (stdin not a tty). We use this to keep defaults safe.
NON_INTERACTIVE=0
[ ! -t 0 ] && NON_INTERACTIVE=1

# Resolve which agents to install for
if [ "$AGENT" = "all" ] || [ "$AGENT" = "auto" ]; then
  AGENT_LIST="claude codex cursor windsurf aider"
else
  AGENT_LIST=$(echo "$AGENT" | tr ',' ' ')
fi

echo "▸ Installing Archimedes Agent Directives → $TARGET"
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

# --- Master file ---
copy_file "$SCRIPT_DIR/AGENT.md" "$TARGET/AGENT.md" "AGENT.md"

# --- Agent-specific aliases (copies, not symlinks — Windows-safe) ---
for TOOL in $AGENT_LIST; do
  case "$TOOL" in
    claude)
      copy_file "$SCRIPT_DIR/AGENT.md" "$TARGET/CLAUDE.md" "CLAUDE.md        (Claude Code)"
      ;;
    codex)
      copy_file "$SCRIPT_DIR/AGENT.md" "$TARGET/AGENTS.md" "AGENTS.md        (Codex)"
      ;;
    cursor)
      copy_file "$SCRIPT_DIR/AGENT.md" "$TARGET/.cursorrules" ".cursorrules     (Cursor)"
      ;;
    windsurf)
      copy_file "$SCRIPT_DIR/AGENT.md" "$TARGET/.windsurfrules" ".windsurfrules   (Windsurf)"
      ;;
    aider)
      copy_file "$SCRIPT_DIR/AGENT.md" "$TARGET/CONVENTIONS.md" "CONVENTIONS.md   (Aider)"
      # Aider needs explicit activation via .aider.conf.yml
      if [ ! -f "$TARGET/.aider.conf.yml" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
          echo "  → would write     .aider.conf.yml (read: CONVENTIONS.md)"
        else
          cat > "$TARGET/.aider.conf.yml" <<'YML'
# Aider configuration — auto-load Archimedes directives.
read: CONVENTIONS.md
YML
          echo "  ✓ .aider.conf.yml  (auto-loads CONVENTIONS.md)"
        fi
      else
        echo "  · .aider.conf.yml already present — add 'read: CONVENTIONS.md' manually"
      fi
      ;;
  esac
done

# --- Claude Code hooks ---
if echo " $AGENT_LIST " | grep -q " claude "; then
  [ "$DRY_RUN" -eq 0 ] && mkdir -p "$TARGET/.claude/hooks"
  copy_file "$SCRIPT_DIR/.claude/settings.json" "$TARGET/.claude/settings.json" ".claude/settings.json"
  if [ "$DRY_RUN" -eq 0 ]; then
    for H in "$SCRIPT_DIR/.claude/hooks/"*.sh; do
      [ -f "$H" ] || continue
      cp "$H" "$TARGET/.claude/hooks/$(basename "$H")"
    done
    chmod +x "$TARGET/.claude/hooks/"*.sh
    HOOK_COUNT=$(ls "$TARGET/.claude/hooks/"*.sh 2>/dev/null | wc -l | tr -d ' ')
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

# --- Skills ---
if [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p "$TARGET/skills"
  for F in "$SCRIPT_DIR/skills/"*; do
    [ -f "$F" ] || continue
    DST="$TARGET/skills/$(basename "$F")"
    if [ "$NO_OVERWRITE" -eq 1 ] && [ -e "$DST" ]; then
      echo "  · skip (exists)    skills/$(basename "$F")"
      continue
    fi
    cp "$F" "$DST"
  done
  chmod +x "$TARGET/skills/"*.sh 2>/dev/null || true
  echo "  ✓ skills/          (progressive disclosure)"
else
  echo "  → would write     skills/*"
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

# --- Universal git hook fallback ---
IN_GIT=0
if git -C "$TARGET" rev-parse --is-inside-work-tree &>/dev/null; then IN_GIT=1; fi

if [ "$IN_GIT" -eq 1 ]; then
  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$TARGET/.githooks"
    cp "$SCRIPT_DIR/.githooks/pre-commit" "$TARGET/.githooks/pre-commit"
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
if [ "$IN_GIT" -eq 1 ] && [ "$GITHOOKS" = "no" ]; then
  echo "  5. (Optional) Enable universal hooks: git config core.hooksPath .githooks"
fi
