Invoke the `wiki-agent` to generate a product wiki at `docs/wiki/`.

**Begin by outputting:**
```
Wiki generator starting...
```

## What This Does

1. Detects your app type and framework
2. Discovers every route, page, and screen
3. Attempts screenshot capture (needs app running + Playwright/Puppeteer/Chromium)
4. Reads each page's source to understand its features
5. Compares to `spec/SPEC.md` if one exists
6. Asks clarifying questions about anything that couldn't be determined from code
7. Writes structured markdown to `docs/wiki/`

## Subdirectory Mode

```bash
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
CATHY_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
if [ "$GIT_ROOT" != "$CATHY_DIR" ]; then
  echo "SUBDIRECTORY_MODE: true — targeting $GIT_ROOT"
  cd "$GIT_ROOT"
fi
```

If in subdirectory mode, all `docs/wiki/` output paths and all source file reads use the parent project root.

## Invoke the Agent

Invoke `wiki-agent` with full context:

- The current working directory (or parent if subdirectory mode)
- Whether `spec/SPEC.md` exists
- Any path or description passed as an argument to this command (e.g., `/project:wiki --url=http://localhost:4000` to use a custom base URL for screenshots)
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
  • Start your app and re-run /project:wiki to capture screenshots
  • Edit docs/wiki/index.md to add context the agent couldn't infer from code
  • If the spec comparison shows unbuilt features, run /project:spec-check for full detail
  • Commit docs/wiki/ to keep it in sync with the codebase
```
