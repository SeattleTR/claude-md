# Skills — Progressive Tool Disclosure

Rather than loading every tool schema into the agent's prompt, specialized
scripts live here. The agent discovers them on demand via
`discover_tools.sh`, retrieving only the syntax needed for the current
atomic task.

## Usage

    ./skills/discover_tools.sh            # list every available skill
    ./skills/discover_tools.sh <query>    # search by keyword
    ./skills/<skill-name>.sh [args]       # execute a skill

## Bundled Skills

- `discover_tools.sh` — meta-skill; searches other skills
- `playwright-capture.sh` — headless browser screenshot for UI validation

## Adding a Skill

1. Create `skills/<name>.sh` (or `<name>.md` for docs-only skills).
2. The first 1–2 comment lines must describe what the skill does.
   `discover_tools` uses them as the search snippet.
3. Keep each skill self-contained. No side effects on load, only on
   execution.
4. Document required dependencies in the header.

## Philosophy

Every tool schema in the prompt competes with task context. A 200-tool
MCP server eats ~20K tokens before the agent reads a single file. Skills
invert that: zero tokens until the agent asks, then only what it needs.

Prefer **Code Mode** — a local script that bundles multiple API calls in
one execution — over N sequential JSON tool invocations. Lower latency,
lower token usage, easier to debug with a real stack trace.
