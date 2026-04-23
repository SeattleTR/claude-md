# agent-md

**Archimedes Agent Directives** — production-grade directives and hooks for autonomous coding agents. Cross-stack: Claude Code, Codex, Cursor, Windsurf, Aider.

Formerly `claude-md` (v1–v3). Now multi-agent and memory-aware.

## Quickstart

```bash
# From inside your project directory
curl -sL https://raw.githubusercontent.com/iamfakeguru/agent-md/main/install.sh | bash
```

You get:
- `AGENT.md` + per-agent aliases (`CLAUDE.md`, `AGENTS.md`, `.cursorrules`, `.windsurfrules`, `CONVENTIONS.md`)
- `.claude/hooks/` — 7 Claude Code hooks (lint, type-check, tests, state, sensory, TDD, destructive-command block)
- `memory/` — 4-file persistent state system (`agents.md`, `plan.md`, `progress.md`, `verify.md`, `gotchas.md`)
- `skills/` — progressive tool disclosure (agent queries instead of loading all schemas)
- `.githooks/pre-commit` — universal enforcement that works for any agent or bare git

## The Problem

Coding agents have structural failure modes that compound into hours of lost work:

- They say "Done" when the code doesn't compile
- They lose the codebase mid-refactor (context compacts silently at ~167K tokens)
- They apply band-aid fixes instead of real ones
- They hallucinate after ~15 messages
- They rename functions and miss half the callers
- They have no persistent memory — every session restarts from zero
- They self-grade ("looks good") instead of actually validating

## The Fix — Three Layers

**Markdown directives** (`AGENT.md`) handle judgment: planning discipline, TDD, multisensory validation, the CRISPY pipeline, the 2.1 step rule. Every supported agent reads the same source of truth.

**Hooks** (`.claude/hooks/`) mechanically enforce verification in Claude Code. For non-Claude agents, `.githooks/pre-commit` is the universal fallback — runs on every `git commit` regardless of which agent wrote the code.

**Persistent state** (`memory/`) is the 4-file memory system. Agents read `agents.md`, `plan.md`, `progress.md`, `verify.md` at session start and update them as work progresses. Chat history isn't memory.

## What's Inside

```
your-project/
  AGENT.md               # Master directives (source of truth)
  CLAUDE.md              # Copy for Claude Code
  AGENTS.md              # Copy for Codex
  .cursorrules           # Copy for Cursor
  .windsurfrules         # Copy for Windsurf
  CONVENTIONS.md         # Copy for Aider
  .claude/
    settings.json
    hooks/
      post-edit-verify.sh       # lint after every file write
      stop-verify.sh            # type-check + lint + tests at task end
      state-enforcement.sh      # block Stop unless memory/progress.md updated
      sensory-validation.sh     # require visual check for UI changes
      tdd-check.sh              # warn on new exports without tests
      truncation-check.sh       # detect truncated tool output
      block-destructive.sh      # block rm -rf, DROP TABLE, .env reads, force push
  memory/
    agents.md            # sub-agents, MCPs, tech stack
    plan.md              # macro design (vertical slices)
    progress.md          # atomic task checklist (temporal anchor)
    verify.md            # definition of done
    gotchas.md           # mistake log
  skills/
    discover_tools.sh    # query skills on-demand (no schema bloat)
    playwright-capture.sh    # headless screenshot for visual validation
  .githooks/
    pre-commit           # universal enforcement for any agent + bare git
```

## Install Options

```bash
# Auto-detect all agents (default)
./install.sh /path/to/project

# Specific agent(s)
./install.sh --agent=claude /path/to/project
./install.sh --agent=codex,cursor .

# Skip git hooks prompt
./install.sh --no-githooks .
./install.sh --githooks .
```

Required: `jq` (Claude Code hook JSON parsing), `git`, and your language's toolchain.

## What It Fixes

| Problem | Layer | Mechanism |
|---|---|---|
| "Done" with 40 type errors | hooks + .githooks | `stop-verify` / `pre-commit` blocks completion until tsc/eslint/tests pass |
| Lint errors accumulate across edits | hooks | `post-edit-verify` runs lint per file write |
| `rm -rf`, `DROP TABLE`, `.env` exfil | hooks | `block-destructive` denies before execution |
| Grep finds 3 results; there are 47 | hooks | `truncation-check` warns when output was cut |
| No memory between sessions | memory/ | 4-file state system read/written each session |
| Completion without progress update | hooks + .githooks | `state-enforcement` blocks Stop unless `progress.md` changed |
| UI bugs that pass type-check | hooks | `sensory-validation` requires screenshot review for UI diffs |
| Implementation without a test | hooks | `tdd-check` flags new exports without matching tests |
| Tool schema bloat | skills/ | `discover_tools` queries skills on-demand |
| Band-aid fixes | AGENT.md | Senior dev override directive |
| Context decay on large refactors | AGENT.md | Sub-agent swarming directive |
| Rename misses dynamic imports | AGENT.md | Grep-is-not-AST rule + reference-type checklist |
| Agent builds before understanding | AGENT.md | CRISPY 200-line spec before code |
| Outrunning headlights | AGENT.md | 2.1 rule — max 1-3 atomic steps per turn |
| Self-grading UI ("looks right") | AGENT.md + hook | Independent verification required |

## Supported Agents

| Agent | Reads | Native hooks? | Fallback |
|---|---|---|---|
| Claude Code | `CLAUDE.md` | Yes — `.claude/hooks/` | — |
| Codex (OpenAI) | `AGENTS.md` | No | `.githooks/pre-commit` |
| Cursor | `.cursorrules` | No | `.githooks/pre-commit` |
| Windsurf | `.windsurfrules` | No | `.githooks/pre-commit` |
| Aider | `CONVENTIONS.md` | No | `.githooks/pre-commit` |
| Any other | `AGENT.md` (if configured) | No | `.githooks/pre-commit` |

## Migrating from `claude-md` v3

Your existing setup remains compatible:
- GitHub's automatic redirect handles old `iamfakeguru/claude-md` URLs
- Existing `CLAUDE.md` is backed up to `CLAUDE.md.bak` before install writes the new one
- `.claude/hooks/` gains three new hooks alongside the four v3 ones
- `install.sh --agent=claude` reproduces the v3 subset if you want to stay minimal

Re-run `./install.sh` to pick up v4 features.

## Philosophy — The Physics / Topography Split

Hooks are **physics** — inescapable, mechanical, unbypassable under context pressure. They enforce what can be mechanically checked: did it compile, lint, pass tests, did `progress.md` get updated, was a screenshot taken.

Markdown is **topography** — the terrain the agent navigates. It carries intent, strategy, and taste. It can be forgotten under context pressure, but the 4-file memory system provides a persistent surface that survives compaction.

**Rule of thumb:** if an instruction can be forgotten or rationalized away, it belongs in a hook. Everything else goes in markdown.

## What This Doesn't Fix

- **Context compaction** still fires at ~167K tokens in Claude Code. The `memory/` system mitigates it (state survives compaction) but doesn't prevent it.
- **Provider-specific quirks** — Codex, Cursor, etc. have their own context windows and compaction heuristics. Directives are cross-stack; enforcement quality varies.
- **Model taste** — models still lack judgment in edge cases. That's why the human reviews the 200-line spec, not the 5,000-line PR.

## License

MIT.

## Credits

Built by [@iamfakeguru](https://x.com/iamfakeguru). Multi-agent systems at [@OpenServAI](https://x.com/openservai).

Archimedes concepts distilled from the 2026 AIE Europe summits and accompanying research on agentic engineering constraints — stripped of marketing and kept to what's actually implementable from outside the model provider.

Full technical breakdown: [x.com/iamfakeguru/status/2038965567269249484](https://x.com/iamfakeguru/status/2038965567269249484)
