**Begin by outputting:** `[ Manta Enterprise — Update Docs ]`

Update project documentation: README.md and CHANGELOG.md based on recent changes. Optionally pass a specific message: `/project:update-docs "Added OAuth2 authentication"`

## Instructions

You are updating project documentation. Context: **$ARGUMENTS**

### Step 1: Understand recent changes

```bash
git log --oneline -10
git diff HEAD~1 --stat
git diff HEAD~1
```

Read the recent diff to understand what changed.

### Step 2: Run doc-keeper agent

Use the **doc-keeper** agent to:
1. Analyze changes
2. Update README.md if needed
3. Append to CHANGELOG.md
4. Flag any code needing inline documentation

### Step 3: Check for stale documentation

Search for potential stale content:

```bash
# Find all markdown files
find . -name "*.md" -not -path "*/node_modules/*" -not -path "*/.git/*"
```

For each markdown file (besides README and CHANGELOG):
- Check if it references code, APIs, or configs that have changed
- Flag stale sections for user review

### Step 4: API documentation

If the project has API routes, check if they're documented:

```bash
# Find route definitions (adjust for framework)
grep -r "router\.\|app\.get\|app\.post\|@Get\|@Post\|@app\.route" --include="*.ts" --include="*.py" --include="*.go" -l
```

For each route file:
- Is it documented in README or a dedicated API doc?
- If the route was changed recently, is the documentation up to date?

### Step 5: Environment variables

Check for undocumented env vars:

```bash
# Find env var usage
grep -r "process\.env\.\|os\.environ\|os\.getenv\|viper\.Get" --include="*.ts" --include="*.js" --include="*.py" --include="*.go" -h | grep -oE '[A-Z_]{3,}' | sort -u
```

Compare against:
- `.env.example` (if exists)
- README environment variables section

Flag any env vars in code but not in docs.

### Output

```
=== Documentation Update ===

README.md: [Updated|No changes needed]
[What was changed]

CHANGELOG.md: [Updated|No changes needed]
[Entry that was added]

Stale documentation found:
[List of files with potentially stale content, or "None"]

Undocumented env vars:
[List, or "None"]

=== Done ===
```

## Next Steps

```
Next steps:
  → git add README.md CHANGELOG.md && git commit    commit doc updates
  → /project:release [patch|minor|major]            cut a release if ready
  → /project:audit                                  run full health report
```
