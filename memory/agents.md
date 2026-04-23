# Sub-Agents & Tooling Registry

Update this file when sub-agents, MCPs, or core dependencies change.
Read at every session start.

## Active Sub-Agents

<!--
List each sub-agent the orchestrator may delegate to. Example:

- **general-purpose** — research, multi-file search, open-ended questions
- **code-reviewer** — second-opinion reviews before merging
- **explorer** — fast codebase mapping for unfamiliar directories
-->

## MCPs / External Services

<!--
List MCP servers or external tools the agent can invoke. Example:

- Playwright — visual validation (screenshots, click automation)
- Anthropic API — VLM for screenshot review
- Postgres MCP — read-only DB introspection
-->

## Tech Stack

<!--
Runtime, language, framework, version. Example:

- Runtime: Node 20+
- Language: TypeScript 5.8 (strict, erasableSyntaxOnly)
- Framework: Next.js 14 (app router)
- Test: Vitest
- Lint: eslint + ruff
- Type-check: tsc --noEmit
-->

## Forbidden Patterns

<!--
Project-specific patterns this agent must not introduce. Example:

- No `any` types. Use `unknown` + type guards.
- No dynamic imports. Static imports only.
- No default exports on shared utilities.
- No silent catches. Errors hard-crash or are explicitly re-thrown.
-->
