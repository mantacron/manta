**Begin by outputting:** `[ Manta Enterprise — Audit ]`

Run a full codebase health audit across security, code quality, and performance.
Output: `reports/YYYY-MM-DD-report.md` with findings, health score, and quick wins.

Accepts an optional focus flag: `security`, `quality`, `performance`.
If a focus is specified, run only the relevant agent. Otherwise run all.

---

## Review Depth

Accepts `--depth=quick|standard|deep` (default: `standard`). Depth sets the **budget
and rigor** of each agent — it does not change *which* agents run (that is trigger
routing, decided separately).

| Depth | Full-file reads/agent | Findings reported | Severities | Model override |
|-------|----------------------|-------------------|------------|----------------|
| `quick` | ≤5, grep-first only | top 5 per severity | CRITICAL only | `sonnet` for every agent |
| `standard` | ≤15 | top 10 per severity | CRITICAL + WARNING | agent default (frontmatter) |
| `deep` | ≤50, trace data flow across files | all findings, no truncation | CRITICAL + WARNING + INFO | `opus` for analysis agents |

Pass the resolved caps into every agent prompt as `READ_CAP` and `FINDING_CAP`, and
pass the model override (when the depth defines one) as the Agent tool's `model`
parameter, which takes precedence over the agent's frontmatter.

`quick` is for triage — "is anything on fire?" — on large repos or in a tight loop.
`deep` disables truncation and tells agents to follow data flow across file
boundaries instead of stopping at the first grep hit; use it for release gates,
quarterly audits, and compliance evidence. When in doubt, use `standard`.

---

## Step 0 — Load Suppressions

```bash
cat .mantaignore 2>/dev/null
```

Parse `.mantaignore` if present. Apply suppression rules when assembling findings: if a finding's file path matches the glob and issue description matches the keyword, exclude it from the report and score. Append a `Suppressions` line to the report noting how many were suppressed.

---

## Step 1 — Gather Context

```bash
cat package.json 2>/dev/null | head -20
cat pyproject.toml 2>/dev/null | head -20
cat go.mod 2>/dev/null | head -10
cat Cargo.toml 2>/dev/null | head -10

git log --oneline -1 2>/dev/null
git rev-parse --short HEAD 2>/dev/null
git branch --show-current 2>/dev/null

find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.rb" -o -name "*.java" -o -name "*.php" \) \
  ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/dist/*" ! -path "*/build/*" ! -path "*/vendor/*" \
  2>/dev/null | wc -l

ls reports/ 2>/dev/null | grep -E "report\.md$" | sort | tail -5

# Shared project map — built once, passed to every agent
bash scripts/build-project-map.sh 2>/dev/null || true
cat .manta-cache/project-map.json 2>/dev/null
```

Set internal variables:
```
AUDIT_DATE: <YYYY-MM-DD>
AUDIT_COMMIT: <short SHA>
AUDIT_BRANCH: <branch name>
AUDIT_PROJECT: <name from package.json/pyproject/go.mod/Cargo.toml or directory name>
AUDIT_FOCUS: <flag if provided, otherwise "all">
PREVIOUS_REPORT: <path to most recent *-report.md in reports/ if any>
HAS_MIGRATIONS: <true if migration files exist>
```

Check for migration files:
```bash
find . \( -path "*/migrations/*" -o -path "*/migrate/*" -o -name "*_migration*" \) \
  ! -path "*/.git/*" ! -path "*/node_modules/*" 2>/dev/null | head -5
```

Announce:
> "Auditing **[AUDIT_PROJECT]** @ `[AUDIT_COMMIT]` on `[AUDIT_BRANCH]`
> Running: [list of agents]
> Previous report: [date or "none — this will be your baseline"]"

---

## Step 2 — Run Agents in Parallel

Launch all applicable agents simultaneously as background tasks. Each agent audits the **full codebase**, not a git diff — but "full codebase" means full *scope*, not reading every file. Include this token budget in every agent prompt, along with the project-map JSON from Step 1:

> **Token budget**: Use the provided project map (`high_risk_files`, `api_files`, `migration_files`, `entry_points`, `stack`) instead of re-discovering the repo. Grep for signal patterns first; read a file in full only when a grep hit needs surrounding context. Cap full-file reads at `READ_CAP` files — prioritize high_risk_files and entry points. Report at most the top `FINDING_CAP` findings per severity level, ranked by impact; summarize the rest as counts. Do not paste file contents into your findings — cite `file:line` instead.

Substitute `READ_CAP` and `FINDING_CAP` with the values the resolved depth defines (see **Review Depth** above; `standard` = 15 and 10). At `--depth=deep`, drop the `FINDING_CAP` sentence entirely and instruct agents to trace data flow across file boundaries rather than stopping at the first grep hit.

### Always run (unless focus flag excludes them):

**Agent: `security-sentinel`**
- Scope: ALL source files + dependency manifests + config files
- Focus: secrets, injection vulnerabilities, auth/authz patterns, OWASP Top 10, dependency CVEs

**Agent: `code-quality`**
- Scope: ALL source files
- Focus: DRY violations, cyclomatic complexity hotspots, dead code, naming issues
- Report the top 10 worst offenders by file — not every instance

**Agent: `perf-analyzer`**
- Scope: ALL source files
- Focus: N+1 query patterns, O(n²) algorithms, blocking async calls, memory leak patterns, missing pagination

**Agent: `blueprint-agent`**
- Scope: Full codebase
- Output: generate/update `docs/BLUEPRINT.md` — stack map, API inventory, ER diagram, module map
- This runs in parallel with the others; its output is a file, not findings

### Conditional:

**Agent: `db-migration-guardian`** — only if `HAS_MIGRATIONS = true`
- Scope: all migration files
- Focus: blocking operations on large tables, missing rollbacks, unsafe NOT NULL constraints, index creation without CONCURRENTLY

---

## Step 3 — Deduplicate, Then Calculate Health Score

Before scoring, deduplicate across agents: if `security-sentinel` and `code-quality` both flag the same file:line for the same root cause, count it once at the higher severity and note both sources — `(flagged by: security-sentinel, code-quality)`. Only merge genuine overlaps; two different problems on the same line stay separate. Skipping this step double-penalizes the score for issues that just happen to be visible from two angles.

```
Base score: 100

Deductions:
  Each CRITICAL finding:  -8 points (max -40)
  Each WARNING finding:   -2 points (max -20)
  Each INFO finding:      -0.5 points (max -5)

Category bonuses:
  Security clean (0 findings): +5
  No CRITICAL in any category: +5

Floor: 0. Cap: 100.
```

Score bands:
- **90–100** — Excellent
- **75–89**  — Good
- **60–74**  — Needs Attention
- **40–59**  — Poor
- **0–39**   — Critical State

---

## Step 4 — Trend Comparison

If `PREVIOUS_REPORT` exists:
```bash
cat <PREVIOUS_REPORT>
```

Extract the previous score and finding counts. Calculate:
- Score delta: +N / -N
- New issues (not in previous): list titles
- Resolved issues (in previous, gone now): list titles
- Persistent issues (in both): list titles

If no previous report: note "This is your baseline."

---

## Step 5 — Quick Wins

From all findings, identify the top 3 by:
```
score = (severity_weight × affected_file_count) / fix_complexity
```
Where fix_complexity: 1 = one-liner, 2 = small refactor, 3 = significant work.

These become the "Quick Wins" section.

---

## Step 6 — Write Report

```bash
mkdir -p reports
```

Write to `reports/YYYY-MM-DD-report.md`. If today's report exists, use `reports/YYYY-MM-DD-2-report.md`.

### Report Structure

```markdown
# Health Report — [PROJECT_NAME]

**Date**: YYYY-MM-DD
**Commit**: `[SHA]` on `[branch]`
**Scope**: Full codebase audit ([N] source files)
**Previous report**: [date or "none — baseline"]

---

## Overall Health Score

[SCORE]/100 — [Band label]
████████████████░░░░

| Category       | Score  | CRITICALs | WARNINGs | INFOs |
|----------------|--------|-----------|----------|-------|
| Security       | XX/100 | N         | N        | N     |
| Code Quality   | XX/100 | N         | N        | N     |
| Performance    | XX/100 | N         | N        | N     |
| DB Migrations  | XX/100 | N         | N        | N     |  ← omit if no migrations

---

## Codebase Map

Blueprint generated: `docs/BLUEPRINT.md`
[2–3 sentence summary of what blueprint-agent found: stack, entry points, key modules]

---

## Trend

[Only if previous report exists]
Score: [previous] → [current] ([delta])
New: [N] · Resolved: [N] · Persistent: [N]

---

## Executive Summary

[3 sentences. Overall state, top risks, what to prioritize. No jargon.]

---

## Quick Wins

### 1. [Title] — [CRITICAL|WARNING]
**Impact**: [Why this matters]
**Effort**: [Low|Medium] — [what the fix involves]
**Location**: `file:line`
**Fix**: [Concrete action]

### 2. [Title]
[same]

### 3. [Title]
[same]

---

## Critical Findings — Must Fix

[If none: "✅ No critical findings."]

### Security

#### CRITICAL: [Title]
**File**: `path/to/file.ext:line`
**Issue**: [What is wrong and why it matters]
**Fix**: [Specific action]

### Code Quality
[same structure]

### Performance
[same structure]

### Database Migrations
[same structure, only if HAS_MIGRATIONS]

---

## Warnings — Fix Soon

[Group by category. If none: "✅ No warnings." Cap at 20 total.]

---

## Informational

[Top 10 only. Omit if none.]

---

## Suppressions

[N] findings suppressed via `.mantaignore`. Rules applied: [list]

---

<details>
<summary>Full agent outputs</summary>

### security-sentinel
[full output]

### code-quality
[full output]

### perf-analyzer
[full output]

### db-migration-guardian
[full output, only if ran]

</details>
```

---

## Step 7 — Print Summary and Offer Fix Mode

```
╔══════════════════════════════════════════════════════════╗
║  Audit Complete: [PROJECT_NAME]                          ║
╚══════════════════════════════════════════════════════════╝

  Health Score:  [XX]/100 ([band]) [↑N / ↓N / baseline if first run]

  CRITICAL       [N]  ← must fix
  WARNING        [N]  ← fix before pushing
  INFO           [N]  ← optional

  Blueprint:     docs/BLUEPRINT.md
  Report:        reports/[YYYY-MM-DD]-report.md

  Quick wins:
    1. [title] ([file])
    2. [title] ([file])
    3. [title] ([file])
```

Then ask:

> "Want me to generate fix suggestions for the **[N] critical** findings? I'll read only the flagged files and output concrete, copy-paste-ready fixes."

If yes: invoke the **remediation-agent** with the CRITICAL findings as input. Output to stdout only — no additional file written.

---

## Focus Flags

- `/audit security`     — run only `security-sentinel`
- `/audit quality`      — run only `code-quality`
- `/audit performance`  — run only `perf-analyzer`

Focused reports use the same format but populate only the relevant section.
Filename: `reports/YYYY-MM-DD-[focus]-audit.md`
