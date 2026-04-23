#!/bin/bash
# install.sh — Archimedes Agent Directives installer
#
# Usage:
#   ./install.sh                                    # current dir, auto-detect agents
#   ./install.sh /path/to/project                   # specific target, all agents
#   ./install.sh --agent=claude /path/to/project    # Claude Code only
#   ./install.sh --agent=codex,cursor .             # multiple specific
#   ./install.sh --no-githooks /path/to/project     # skip universal fallback
#
# Or via curl (from inside your project dir):
#   curl -sL https://raw.githubusercontent.com/iamfakeguru/agent-md/main/install.sh | bash
#
# Agents supported: claude, codex, cursor, windsurf, aider, all (default)

set -e

AGENT="all"
TARGET=""
GITHOOKS="ask"

for ARG in "$@"; do
  case $ARG in
    --agent=*)    AGENT="${ARG#*=}" ;;
    --githooks)   GITHOOKS="yes" ;;
    --no-githooks) GITHOOKS="no" ;;
    --help|-h)
      sed -n '2,16p' "$0"; exit 0 ;;
    *)
      [ -z "$TARGET" ] && TARGET="$ARG"
      ;;
  esac
done

TARGET="${TARGET:-.}"

if [ ! -d "$TARGET" ]; then
  echo "Error: target directory does not exist: $TARGET"; exit 1
fi

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

# Resolve which agents to install for
if [ "$AGENT" = "all" ] || [ "$AGENT" = "auto" ]; then
  AGENT_LIST="claude codex cursor windsurf aider"
else
  AGENT_LIST=$(echo "$AGENT" | tr ',' ' ')
fi

echo "▸ Installing Archimedes Agent Directives → $TARGET"
echo "▸ Target agents: $AGENT_LIST"
echo ""

backup_if_exists() {
  if [ -f "$1" ]; then
    mv "$1" "$1.bak"
    echo "  ! backed up existing $(basename "$1") → $(basename "$1").bak"
  fi
}

# --- Master file ---
backup_if_exists "$TARGET/AGENT.md"
cp "$SCRIPT_DIR/AGENT.md" "$TARGET/AGENT.md"
echo "  ✓ AGENT.md"

# --- Agent-specific aliases (copies, not symlinks — Windows-safe) ---
for TOOL in $AGENT_LIST; do
  case "$TOOL" in
    claude)
      backup_if_exists "$TARGET/CLAUDE.md"
      cp "$SCRIPT_DIR/AGENT.md" "$TARGET/CLAUDE.md"
      echo "  ✓ CLAUDE.md        (Claude Code)"
      ;;
    codex)
      backup_if_exists "$TARGET/AGENTS.md"
      cp "$SCRIPT_DIR/AGENT.md" "$TARGET/AGENTS.md"
      echo "  ✓ AGENTS.md        (Codex)"
      ;;
    cursor)
      backup_if_exists "$TARGET/.cursorrules"
      cp "$SCRIPT_DIR/AGENT.md" "$TARGET/.cursorrules"
      echo "  ✓ .cursorrules     (Cursor)"
      ;;
    windsurf)
      backup_if_exists "$TARGET/.windsurfrules"
      cp "$SCRIPT_DIR/AGENT.md" "$TARGET/.windsurfrules"
      echo "  ✓ .windsurfrules   (Windsurf)"
      ;;
    aider)
      backup_if_exists "$TARGET/CONVENTIONS.md"
      cp "$SCRIPT_DIR/AGENT.md" "$TARGET/CONVENTIONS.md"
      echo "  ✓ CONVENTIONS.md   (Aider)"
      ;;
  esac
done

# --- Claude Code hooks ---
if echo " $AGENT_LIST " | grep -q " claude "; then
  mkdir -p "$TARGET/.claude/hooks"
  backup_if_exists "$TARGET/.claude/settings.json"
  cp "$SCRIPT_DIR/.claude/settings.json" "$TARGET/.claude/settings.json"
  for H in "$SCRIPT_DIR/.claude/hooks/"*.sh; do
    [ -f "$H" ] || continue
    cp "$H" "$TARGET/.claude/hooks/$(basename "$H")"
  done
  chmod +x "$TARGET/.claude/hooks/"*.sh
  HOOK_COUNT=$(ls "$TARGET/.claude/hooks/"*.sh 2>/dev/null | wc -l | tr -d ' ')
  echo "  ✓ .claude/         (settings + ${HOOK_COUNT} hooks)"
fi

# --- Memory system (don't overwrite user's state) ---
mkdir -p "$TARGET/memory"
for F in agents.md plan.md progress.md verify.md gotchas.md; do
  if [ ! -f "$TARGET/memory/$F" ] && [ -f "$SCRIPT_DIR/memory/$F" ]; then
    cp "$SCRIPT_DIR/memory/$F" "$TARGET/memory/$F"
  fi
done
echo "  ✓ memory/          (4-file state system)"

# --- Skills ---
mkdir -p "$TARGET/skills"
for F in "$SCRIPT_DIR/skills/"*; do
  [ -f "$F" ] || continue
  cp "$F" "$TARGET/skills/$(basename "$F")"
done
chmod +x "$TARGET/skills/"*.sh 2>/dev/null || true
echo "  ✓ skills/          (progressive disclosure)"

# --- Universal git hook fallback ---
IN_GIT=0
if git -C "$TARGET" rev-parse --is-inside-work-tree &>/dev/null; then IN_GIT=1; fi

if [ "$IN_GIT" -eq 1 ]; then
  mkdir -p "$TARGET/.githooks"
  cp "$SCRIPT_DIR/.githooks/pre-commit" "$TARGET/.githooks/pre-commit"
  chmod +x "$TARGET/.githooks/pre-commit"

  if [ "$GITHOOKS" = "ask" ]; then
    if [ -t 0 ]; then
      printf "▸ Enable git pre-commit hooks (universal enforcement, works in any agent)? [Y/n] "
      read -r REPLY
      REPLY="${REPLY:-Y}"
    else
      REPLY="Y"  # non-interactive (curl pipe) → default yes
    fi
    case "$REPLY" in Y|y|yes|Yes) GITHOOKS="yes" ;; *) GITHOOKS="no" ;; esac
  fi

  if [ "$GITHOOKS" = "yes" ]; then
    (cd "$TARGET" && git config core.hooksPath .githooks)
    echo "  ✓ .githooks/       (active — core.hooksPath=.githooks)"
  else
    echo "  ✓ .githooks/       (installed, not active — enable with: git config core.hooksPath .githooks)"
  fi
fi

echo ""
echo "▸ Installation complete."
echo ""
echo "Next steps:"
echo "  1. Read $TARGET/AGENT.md (the master directives)"
echo "  2. Edit memory/plan.md with your project's design"
echo "  3. Start your agent — it reads directives automatically"
if [ "$IN_GIT" -eq 1 ] && [ "$GITHOOKS" = "no" ]; then
  echo "  4. (optional) Enable universal hooks: git config core.hooksPath .githooks"
fi
