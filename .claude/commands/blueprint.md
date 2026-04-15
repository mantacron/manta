# /project:blueprint — Project Blueprint Generator

**Begin by outputting:** `[ Manta — Blueprint ]`

Generates `docs/BLUEPRINT.md` — a living map of the project: stack, architecture diagram, API inventory, DB schema ER diagram, backend module map, and frontend component tree.

Works on:
- **Existing codebases** — scans files, maps reality
- **Spec-only projects** — reads `spec/SPEC.md`, maps intent

---

## Step 1 — Mode Detection

Run these checks silently:

```bash
# Does code exist?
CODE_EXISTS=false
for dir in src app lib backend api; do
  [ -d "$dir" ] && CODE_EXISTS=true && break
done
ls *.go *.py main.go app.py 2>/dev/null && CODE_EXISTS=true || true
ls package.json go.mod requirements.txt pyproject.toml Cargo.toml Gemfile 2>/dev/null && CODE_EXISTS=true || true

# Does spec exist?
SPEC_EXISTS=false
[ -f "spec/SPEC.md" ] && ! grep -q "\[Project Name\]" spec/SPEC.md && SPEC_EXISTS=true || true

echo "CODE_EXISTS=$CODE_EXISTS SPEC_EXISTS=$SPEC_EXISTS"
```

Determine mode:
- `CODE_EXISTS=true` → **mode: existing**
- `CODE_EXISTS=false`, `SPEC_EXISTS=true` → **mode: spec**
- Neither → stop and say: "No code or filled spec found. Run `/project:init` to set up the project first."

---

## Step 2 — Announce and Confirm

Tell the user what was detected and what will be generated:

**Mode: existing**
> "Found an existing codebase. I'll scan it and generate `docs/BLUEPRINT.md` with:
> - Stack summary
> - Architecture diagram (Mermaid)
> - API inventory table
> - DB schema ER diagram (Mermaid)
> - Backend module map with layer dependency diagram
> - Frontend component tree
>
> This may take a moment for large codebases. Proceed? [Y/n]"

**Mode: spec**
> "Found `spec/SPEC.md` but no code yet. I'll generate `docs/BLUEPRINT.md` from the spec — a blueprint of what's planned:
> - Intended stack and architecture
> - Planned API surface (from Section 4)
> - Planned data models as ER diagram (from Section 6)
> - Planned module structure (from Section 2)
>
> Everything will be marked as **planned/not yet implemented**. Proceed? [Y/n]"

If user says no: stop.

---

## Step 3 — Run Blueprint Agent

Invoke the **blueprint-agent** with the detected mode and project root.

Pass:
```
MODE={existing|spec}
PROJECT_ROOT={current directory}
DATE={YYYY-MM-DD}
```

The agent handles all scanning, diagramming, and file generation.

---

## Step 4 — Summary

After the agent completes, print:

```
Blueprint generated: docs/BLUEPRINT.md

  Stack:        {detected stack summary}
  Mode:         {existing | spec-only}
  Routes:       {N} endpoints
  Models:       {N} DB entities
  Components:   {N} frontend components
  Modules:      {N} controllers/services
```

Then:
> "Open `docs/BLUEPRINT.md` to view the full blueprint. Diagrams render in GitHub, VS Code (Markdown Preview), and any Mermaid-compatible viewer.
>
> Re-run `/project:blueprint` anytime to refresh — it overwrites the previous version."
