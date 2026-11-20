## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).

## Atlas engineering constraints

- Preserve existing working functionality. Make one small, clearly scoped change at a time.
- Specify and plan before implementing (see `SPEC.md`, `tasks/`). Stop for review after each task.
- Never invent nutrition values or present an uncertain product match as exact. Missing values stay unknown, never zero.
- Keep API keys and secrets out of the client. Keep the Gemini key server-side.
- Keep the existing Flutter architecture and design system unless a change is approved.
- After changes run the relevant tests and `flutter analyze --fatal-infos --no-pub`.
- Widget tests are not device proof; do not claim device-level success without the owner's phone check.
- Do not commit, push, or make unrelated changes without permission. No paid services or new dependencies without approval.
- More project rules live in `AGENTS.md`, which Claude Code does not load automatically; read it when relevant.
