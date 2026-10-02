**Begin by outputting:** `[ Manta — Wiki ]`

Invoke the `wiki-agent` to generate a product wiki at `docs/wiki/`.

## What This Does

1. Detects your app type and framework
2. Discovers every route, page, and screen
3. Attempts screenshot capture (needs app running + Playwright/Puppeteer/Chromium)
4. Reads each page's source to understand its features
5. Compares to `spec/SPEC.md` if one exists
6. Lists what it could not determine from code, as assumptions to confirm
7. Writes structured markdown to `docs/wiki/`

The agent runs as a sub-agent and cannot stop mid-run for an answer, so tell it
so in the prompt: instead of asking, it writes each open question as an
assumption under **Assumptions to confirm** in `docs/wiki/index.md`, uses its
best reading meanwhile, and returns the list. Show that list at the end. When
the person answers here, record the answers in
`.claude/agent-memory/wiki-agent/MEMORY.md` (clarifications) so the next run
does not ask again. A run with nobody to answer (`claude -p`, CI) writes the
same wiki and the same list.

## Subdirectory Mode

```bash
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
MANTA_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
if [ "$GIT_ROOT" != "$MANTA_DIR" ]; then
  echo "SUBDIRECTORY_MODE: true — targeting $GIT_ROOT"
  cd "$GIT_ROOT"
fi
```

If in subdirectory mode, all `docs/wiki/` output paths and all source file reads use the parent project root.

## Invoke the Agent

Invoke `wiki-agent` with full context:

- The current working directory (or parent if subdirectory mode)
- Whether `spec/SPEC.md` exists
- Any path or description passed as an argument to this command (e.g., `/wiki --url=http://localhost:4000` to use a custom base URL for screenshots)
- Whether the user mentioned any specific pages or features to prioritize

## Output Location

All wiki files are written to `docs/wiki/`:
- `index.md` — overview and navigation
- `getting-started.md` — setup and first steps
- `features.md` — master feature list
- `pages/[slug].md` — one file per route/screen
- `screenshots/[slug].png` — screenshots if captured
- `spec-comparison.md` — gap analysis (only when `spec/SPEC.md` exists)

## After Completion

Report the final summary from the wiki-agent, then suggest next steps:

```
Next steps:
  • Start your app and re-run /wiki to capture screenshots
  • Edit docs/wiki/index.md to add context the agent couldn't infer from code
  • If the spec comparison shows unbuilt features, run /spec-check for full detail
  • Commit docs/wiki/ to keep it in sync with the codebase
```
