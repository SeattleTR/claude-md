#!/bin/bash
# discover_tools.sh — progressive tool disclosure
# Usage:
#   ./skills/discover_tools.sh            # list all skills
#   ./skills/discover_tools.sh <query>    # search skills by keyword
#
# The agent runs this instead of loading every tool schema into context.
# Only the matching skill's header + body enters the prompt.

QUERY="${1:-}"
DIR="$(dirname "$0")"

if [ -z "$QUERY" ]; then
  echo "Available skills in $DIR/:"
  echo ""
  for SCRIPT in "$DIR"/*.sh "$DIR"/*.md; do
    [ -f "$SCRIPT" ] || continue
    NAME=$(basename "$SCRIPT")
    [ "$NAME" = "discover_tools.sh" ] && continue
    [ "$NAME" = "README.md" ] && continue
    DESC=$(head -5 "$SCRIPT" | grep -E '^(#|<!--)' | head -1 | sed -E 's/^(#!\/bin\/bash|#\s*|<!--\s*|-->)//g')
    echo "  • $NAME"
    [ -n "$DESC" ] && echo "    $DESC"
  done
  echo ""
  echo "Run: ./skills/discover_tools.sh <query>  to search by keyword."
  exit 0
fi

MATCHES=$(grep -il "$QUERY" "$DIR"/*.sh "$DIR"/*.md 2>/dev/null | grep -v discover_tools.sh)

if [ -z "$MATCHES" ]; then
  echo "No skills match '$QUERY'."
  echo "Run ./skills/discover_tools.sh (no args) to list all."
  exit 0
fi

for MATCH in $MATCHES; do
  echo "=== $(basename "$MATCH") ==="
  head -25 "$MATCH"
  echo ""
done
