# CLAUDE.md

Production-grade agent directives for Claude Code. Reverse-engineered
from the source, refined against billions of tokens of real agent logs,
and incorporating patterns from Anthropic's own engineering team.

## What This Is

Claude Code has structural bottlenecks that cause predictable failures:
context compaction destroys working memory mid-refactor, file reads
silently truncate at 2,000 lines, tool results get cut to 2,000-byte
previews, the default system prompt biases toward minimal output over
correct output, and the agent has no built-in verification loop between
editing code and reporting success.

This CLAUDE.md overrides all of it. It also adds operational patterns
that Anthropic's engineers use internally but haven't documented in one
place: spec-based development, sub-agent execution models, file system
as state, prompt cache management, and self-improving error prevention.

Full technical breakdown:
[x.com/iamfakeguru/status/2038965567269249484](https://x.com/iamfakeguru/status/2038965567269249484)

## Install

Drop it in your project root:

```bash
curl -o CLAUDE.md https://raw.githubusercontent.com/iamfakeguru/claude-md/main/CLAUDE.md
```

Or clone and copy:

```bash
git clone https://github.com/iamfakeguru/claude-md.git
cp claude-md/CLAUDE.md /path/to/your/project/
```

Claude Code reads CLAUDE.md from the project root automatically.

## What It Fixes

| Problem | Root Cause | Directive |
|---|---|---|
| "Done!" with 40 type errors | Success = bytes on disk, no compile check | Forced Verification |
| Hallucinations after ~15 messages | Auto-compaction nukes context at ~167K tokens | Step 0 + Phased Execution |
| Band-aid fixes instead of real solutions | System prompt mandates minimal intervention | Senior Dev Override |
| Context decay on large refactors | Single agent = single 167K context window | Sub-Agent Swarming |
| Edits reference code it never saw | File reads capped at 2,000 lines | File Read Budget |
| Grep finds 3 results, there are 47 | Tool results truncated to 2,000-byte preview | Tool Result Blindness |
| Rename misses dynamic imports | Grep is text matching, not an AST | No Semantic Search |
| Agent builds before understanding | No plan/build separation by default | Spec-Based Development |
| Same mistakes every session | No cross-session learning | Self-Improvement Loop |
| Context lost between sessions | Starting fresh every time | Session Continuity |
| Agent asks for hand-holding on bugs | Default passivity | Autonomous Bug Fixing |

## Going Further

The CLAUDE.md above handles the general case. For per-filetype
directives, Claude Code supports conditional loading via
`.claude/rules/*.md` with YAML frontmatter:

```markdown
# .claude/rules/tests.md
---
paths:
  - "**/*.test.ts"
  - "**/*.spec.ts"
---
When modifying test files:
- Do not modify production code from this context.
- Use AskUserQuestion if the mocked data schema is unclear.
- Run the specific test file after changes, not the full suite.
```

Testing rules only load when editing test files. Migration rules only
load for migrations. The main CLAUDE.md stays lean while specialized
contexts activate automatically.

You can also set up hooks in `~/.claude/settings.json` to auto-format
or block dangerous commands:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write(*.py)",
        "hooks": [
          {
            "type": "command",
            "command": "python -m black \"$file\""
          }
        ]
      }
    ]
  }
}
```

For the full configuration system (permissions, hooks, custom slash
commands, MCP servers), see the
[Anthropic docs](https://docs.anthropic.com/en/docs/claude-code/overview).

## Works With

- **Claude Code** - reads CLAUDE.md natively
- **Cursor** - paste into `.cursorrules`
- **Other agents** - paste into whatever rules/system prompt file your
  tool uses

## Context

Built by [@fakeguru](https://x.com/iamfakeguru). AI agent
infrastructure. Advisor [@OpenServAI](https://x.com/openservai).

## License

MIT.
