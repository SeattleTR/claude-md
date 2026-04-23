# agent-md

**Archimedes Agent Directives** — cross-agent directives, hooks, and state layout for autonomous coding agents. Works with Claude Code, Codex, Cursor, Windsurf, Aider.

Formerly `claude-md` (v1–v3). Now multi-agent and memory-aware.

Honest scope: the markdown directives are advisory (the agent has to read and follow them). Only the Claude Code hooks and the optional `.githooks/pre-commit` actually block anything — see the enforcement table below.

## Quickstart

```bash
# From inside your project directory
curl -sL https://raw.githubusercontent.com/iamfakeguru/agent-md/main/install.sh | bash
```

You get:
- `AGENT.md` + per-agent aliases (`CLAUDE.md`, `AGENTS.md`, `.cursorrules`, `.windsurfrules`, `CONVENTIONS.md`)
- `.claude/hooks/` — 7 Claude Code hooks (lint, type-check, tests, state, sensory reminder, TDD nudge, destructive-command block)
- `memory/` — 5-file persistent state system (`agents.md`, `plan.md`, `progress.md`, `verify.md`, `gotchas.md`)
- `skills/` — progressive tool disclosure (agent queries instead of loading all schemas)
- `.githooks/pre-commit` — optional git-hook fallback for any agent (disabled until you enable it)

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

**Markdown directives** (`AGENT.md`) carry judgment-heavy guidance: planning discipline, TDD, multisensory validation, the CRISPY pipeline, the 2.1 step rule. Every supported agent reads the same source of truth. Advisory — depends on the agent following what it read.

**Hooks** (`.claude/hooks/`) are where real enforcement lives — for Claude Code. They can block Stop, emit block decisions after edits, and deny destructive Bash calls pre-execution. For non-Claude agents there is an optional `.githooks/pre-commit` that runs on `git commit` — it is installed but NOT active by default (enable with `git config core.hooksPath .githooks`).

**Persistent state** (`memory/`) is a 5-file layout. Agents read `agents.md`, `plan.md`, `progress.md`, `verify.md`, `gotchas.md` at session start and update them as work progresses. Chat history isn't memory.

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
      post-edit-verify.sh       # lint after every file write (block decision)
      stop-verify.sh            # type-check + lint + tests at task end (block)
      state-enforcement.sh      # block Stop unless memory/progress.md updated
      sensory-reminder.sh       # nudge agent to do visual check on UI diffs
      tdd-check.sh              # soft warn on new exports without tests
      truncation-check.sh       # detect truncated tool output
      block-destructive.sh      # deny rm -rf, DROP TABLE, .env reads, force push
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
    pre-commit           # optional fallback — enable with core.hooksPath
```

## Enforcement — What actually blocks

| Check | Claude Code | Codex / Cursor / Windsurf / Aider | Note |
|---|---|---|---|
| Lint after edit | **Hard** (`post-edit-verify.sh`) | Fallback via `pre-commit` (opt-in) | Per-file eslint/ruff |
| Type-check + lint + tests at Stop | **Hard** (`stop-verify.sh`) | Fallback via `pre-commit` (opt-in) | Uses heuristic tool detection |
| `progress.md` stays current | **Hard** (`state-enforcement.sh`) | Fallback via `pre-commit` (opt-in) | Staged diff check |
| Destructive Bash blocked | **Hard** (`block-destructive.sh`) | Not covered | Regex seatbelt, not a security boundary |
| UI → visual validation | **Advisory** (`sensory-reminder.sh`) | Advisory via `AGENT.md` | Injects reminder, does not run Playwright/VLM itself |
| New export → matching test | **Advisory** (`tdd-check.sh`) | Advisory via `AGENT.md` | Grep-based nudge |
| Tool-output truncation | **Advisory** (`truncation-check.sh`) | Not covered | Looks for "Output too large" marker |
| Planning / CRISPY / 2.1 / memory reads | Advisory (`AGENT.md`) | Advisory (`AGENT.md`) | Depends on agent following the file |

"Hard" = the hook can block the agent or commit. "Advisory" = it only injects a reminder the agent may still ignore. "Fallback" = runs on `git commit` if the user ran `git config core.hooksPath .githooks`.

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
| Silent tool-output truncation | hooks | `truncation-check` emits advisory when Claude's output-too-large marker appears |
| No memory between sessions | memory/ | 5-file state system read/written each session |
| Completion without progress update | hooks + .githooks | `state-enforcement` blocks Stop unless `progress.md` changed |
| UI bugs that pass type-check | hooks | `sensory-reminder` nudges agent to screenshot + VLM review |
| Implementation without a test | hooks | `tdd-check` soft-warns on new exports without matching tests |
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
| Codex (OpenAI) | `AGENTS.md` | Experimental — not installed by this repo | `.githooks/pre-commit` (opt-in) |
| Cursor | `.cursorrules` | No | `.githooks/pre-commit` (opt-in) |
| Windsurf | `.windsurfrules` | No | `.githooks/pre-commit` (opt-in) |
| Aider | `CONVENTIONS.md` | No | `.githooks/pre-commit` (opt-in) |
| Any other | `AGENT.md` (if configured) | No | `.githooks/pre-commit` (opt-in) |

Codex has gained experimental native hooks recently, but this repo does not yet install a Codex-native hook bundle — it wires the directives file (`AGENTS.md`) and relies on the git fallback. If/when you want native Codex skills, they live at `.agents/skills/<name>/SKILL.md`. The `skills/` directory in this repo is plain shell scripts for progressive tool disclosure, not Codex-native skill packages.

Aliases are plain copies of `AGENT.md`, not symlinks (Windows-safe). If you edit one, re-run `./install.sh` to re-sync the others — or edit `AGENT.md` and re-run.

## Migrating from `claude-md` v3

Your existing setup remains compatible:
- GitHub's automatic redirect handles old `iamfakeguru/claude-md` URLs
- Existing `CLAUDE.md` is backed up to `CLAUDE.md.bak` before install writes the new one
- `.claude/hooks/` gains three new hooks alongside the four v3 ones
- `install.sh --agent=claude` reproduces the v3 subset if you want to stay minimal

Re-run `./install.sh` to pick up v4 features.

## Philosophy — Contracts, not doctrine

Hooks are closer to physics than prompts: they create deterministic friction outside the model. They're still scoped to the tool, the event, and the bypass rules of the environment — Claude Code hooks can only observe Claude Code's tool calls, and `git commit --no-verify` will sail past the pre-commit hook. What they give you is an artifact-based contract: the commands either exited zero or they didn't.

Markdown is terrain the agent navigates. It carries intent, strategy, and taste. Under context pressure it can be forgotten or rationalized away. The 5-file memory system (`agents.md` / `plan.md` / `progress.md` / `verify.md` / `gotchas.md`) is a persistent surface the agent re-reads on session start so some of that terrain survives compaction.

**Rule of thumb:** if an instruction can be forgotten or rationalized away, try to turn it into a checked artifact (a hook, a committed file, a required evidence note). Everything else goes in markdown — and if it's in markdown, call it advisory. Less doctrine, more contracts.

## What This Doesn't Fix

- **Context compaction** still fires at ~167K tokens in Claude Code. The `memory/` system mitigates it (state survives compaction) but doesn't prevent it.
- **Provider-specific quirks** — Codex, Cursor, etc. have their own context windows and compaction heuristics. Directives are cross-stack; enforcement quality varies.
- **Model taste** — models still lack judgment in edge cases. That's why the human reviews the 200-line spec, not the 5,000-line PR.

## Development

Run the test suite:

```bash
bats tests/
shellcheck .claude/hooks/*.sh skills/*.sh .githooks/pre-commit install.sh
```

CI (GitHub Actions) runs both plus an installer smoke test on every push.

## License

MIT.

## Credits

Built by [@iamfakeguru](https://x.com/iamfakeguru). Multi-agent systems at [@OpenServAI](https://x.com/openservai).

Archimedes concepts distilled from the 2026 AIE Europe summits and accompanying research on agentic engineering constraints — stripped of marketing and kept to what's actually implementable from outside the model provider.

Full technical breakdown: [x.com/iamfakeguru/status/2038965567269249484](https://x.com/iamfakeguru/status/2038965567269249484)
