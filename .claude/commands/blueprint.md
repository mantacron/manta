# /blueprint — Project Blueprint Generator

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
- Neither → stop and say: "No code or filled spec found. Run `/init` to set up the project first."

---

## Step 2 — Announce, and keep any hand edits

Running `/blueprint` is the request, so there is no "Proceed?" — a run with
nobody to answer (`claude -p "/blueprint"`, CI) does exactly what an interactive
one does. Say what was detected and what will be generated:

**Mode: existing**
> "Found an existing codebase. Generating `docs/BLUEPRINT.md` with: stack summary,
> architecture diagram (Mermaid), API inventory, DB schema ER diagram, backend
> module map with layer dependencies, frontend component tree."

**Mode: spec**
> "Found `spec/SPEC.md` but no code yet. Generating `docs/BLUEPRINT.md` from the
> spec — intended stack and architecture, planned API surface, planned data
> models, planned module structure — every item marked **planned/not yet
> implemented**."

A blueprint someone has edited by hand must not be overwritten. Check:

```bash
git status --porcelain -- docs/BLUEPRINT.md 2>/dev/null
```

Any output means `docs/BLUEPRINT.md` holds changes git does not have (modified,
or never committed). Then write the new blueprint to `docs/BLUEPRINT.new.md`
instead — pass `OUTPUT=docs/BLUEPRINT.new.md` in Step 3 — and say so: "Your
docs/BLUEPRINT.md has uncommitted edits, so the new blueprint is in
docs/BLUEPRINT.new.md — compare and replace." A committed blueprint is
overwritten in place; git still has the old one.

---

## Step 3 — Run Blueprint Agent

Invoke the **blueprint-agent** with the detected mode and project root.

Pass:
```
MODE={existing|spec}
PROJECT_ROOT={current directory}
DATE={YYYY-MM-DD}
OUTPUT={docs/BLUEPRINT.md, or docs/BLUEPRINT.new.md from Step 2}
```

and tell the agent to write to `OUTPUT` — not to `docs/BLUEPRINT.md` — when the
two differ.

The agent handles all scanning, diagramming, and file generation.

---

## Step 4 — Summary

After the agent completes, print:

```
Blueprint generated: {OUTPUT}

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
> Re-run `/blueprint` anytime to refresh — it overwrites a committed blueprint; one with uncommitted edits is kept, and the new one written beside it."
