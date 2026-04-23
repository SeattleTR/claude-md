#!/bin/bash
# block-destructive.sh
# PreToolUse hook for Bash commands.
# Blocks obviously destructive operations before they execute.
#
# Scope: this is a SEATBELT, not a security boundary. It catches the
# most common accidental foot-guns (rm -rf /, DROP TABLE, force push,
# .env reads). It does NOT catch every destructive path — e.g.
# `find -delete`, `git clean -fdx`, `dd`, shell aliases, obfuscated
# invocations, or anything you `chmod +x` and run. For real isolation,
# run the agent in a container or VM.

deny() {
  # $1 = reason
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Block recursive deletion of root, home, or parent directory
if echo "$COMMAND" | grep -qE 'rm\s+(-[a-zA-Z]*f[a-zA-Z]*\s+|(-[a-zA-Z]*\s+)*)(\/|~|\$HOME|\.\.)'; then
  deny "Blocked destructive rm command targeting root, home, or parent directory. If intentional, run manually."
fi

# Block find -delete / find -exec rm chains
if echo "$COMMAND" | grep -qE 'find\s+.*(-delete|-exec\s+rm)'; then
  deny "Blocked find -delete / find -exec rm. If intentional, run manually."
fi

# Block git clean -fdx (wipes untracked + ignored files)
if echo "$COMMAND" | grep -qE 'git\s+clean\s+.*-[a-z]*[fx][a-z]*'; then
  deny "Blocked 'git clean -f/-x'. Wipes untracked/ignored files. If intentional, run manually."
fi

# Block database destruction
if echo "$COMMAND" | grep -qiE 'DROP\s+(TABLE|DATABASE)|TRUNCATE\s+TABLE|DELETE\s+FROM\s+\S+\s*;?\s*$'; then
  deny "Blocked destructive database command. If intentional, run manually."
fi

# Block force pushes and hard resets against shared refs
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*--force|git\s+push\s+-f\b|git\s+reset\s+--hard\s+(HEAD~|origin)'; then
  deny "Blocked force push or hard reset. If intentional, run manually."
fi

# Block .env file reads (credential exposure)
if echo "$COMMAND" | grep -qE '(cat|less|head|tail|more|source|grep|sed|awk|bat)\s+\.env\b|echo.*\$\(.*\.env'; then
  deny "Blocked .env file access. Credentials should not be read by the agent."
fi

exit 0
