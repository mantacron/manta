**Begin by outputting:** `[ Manta — Debt Ledger ]`

Harvest `// manta-defer:` inline annotations from the codebase into a structured deferral ledger. Flags intentional shortcuts that have no stated exit condition — the ones that silently rot into permanent tech debt.

## The `// manta-defer:` Convention

When you make an intentional simplification that you plan to revisit later, mark it inline:

```typescript
// manta-defer: in-memory cache, ceiling: >100 concurrent users, trigger: load test shows p95 > 200ms
const cache = new Map();

// manta-defer: single DB connection, ceiling: single-process only, trigger: horizontal scaling needed
const db = await createConnection();

// manta-defer: hardcoded pagination limit, ceiling: <10k records, trigger: table exceeds 10k rows
const LIMIT = 100;
```

Format: `// manta-defer: <what was simplified>, ceiling: <the known limit>, trigger: <when to revisit>`

The `trigger:` field is critical. Entries without one are flagged as `NO-TRIGGER` — the most dangerous category, because there's no stated condition that would prompt revisiting them.

You can use `#` for Python/Ruby/Shell and `--` for SQL:
```python
# manta-defer: sequential processing, ceiling: <1000 items/batch, trigger: batch processing >30s
```

## Usage

```
/project:debt          ← full ledger with all annotations
/project:debt --no-trigger   ← show only entries missing a trigger (highest risk)
/project:debt --by-file      ← group by file instead of severity
```

## Instructions

### Step 1: Detect subdirectory mode

```bash
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
CATHY_DIR=$(pwd)
```

If `GIT_ROOT != CATHY_DIR`, prefix all project paths with `../`.

### Step 2: Harvest annotations

```bash
grep -rn "manta-defer:" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
  --include="*.py" --include="*.go" --include="*.rs" --include="*.rb" \
  --include="*.java" --include="*.kt" --include="*.cs" --include="*.php" \
  --include="*.sh" --include="*.sql" \
  . 2>/dev/null \
  | grep -v "node_modules\|vendor\|dist\|build\|.git\|__pycache__\|.venv\|coverage"
```

For each match, parse:
- **File + line** — from grep output (`file:line:`)
- **What** — everything before `ceiling:` (or the full annotation if no `ceiling:`)
- **Ceiling** — value after `ceiling:` and before `trigger:` (or "unspecified")
- **Trigger** — value after `trigger:` (or `NO-TRIGGER` if absent)

### Step 3: Categorize

Group entries into:

**NO-TRIGGER** — no exit condition stated. These are the highest-risk entries.
```
[file:line] [what was simplified]
  Ceiling:  [stated ceiling or "unspecified"]
  Trigger:  ⚠ NONE — no condition will prompt revisiting this
```

**HAS-TRIGGER** — normal deferred decisions with a clear exit condition.
```
[file:line] [what was simplified]
  Ceiling:  [stated ceiling]
  Trigger:  [when to revisit]
```

### Step 4: Output the ledger

```
╔══════════════════════════════════════════════════════════════════╗
║                     DEBT LEDGER                                  ║
║  [project name]                    [today's date]                ║
╚══════════════════════════════════════════════════════════════════╝

Total deferred decisions: [N]
  ⚠ NO-TRIGGER (rot risk): [N]   ← must add a trigger or resolve
  ✓ Has trigger:           [N]   ← being tracked

[If NO-TRIGGER entries exist:]
══ HIGH RISK — NO EXIT CONDITION ══════════════════════════════════

[For each NO-TRIGGER entry:]
  [file:line]
  What:    [description]
  Ceiling: [ceiling or "unspecified"]
  Trigger: ⚠ NONE

Action: Add `trigger: <condition>` to this annotation, or resolve the shortcut.

[If HAS-TRIGGER entries exist:]
══ TRACKED DEFERRALS ═══════════════════════════════════════════════

[For each HAS-TRIGGER entry:]
  [file:line]
  What:    [description]
  Ceiling: [ceiling]
  Trigger: [condition]

[If no entries found:]
No `// manta-defer:` annotations found in the codebase.
Either the codebase has no intentional shortcuts, or they haven't been annotated yet.
To start tracking: add `// manta-defer: <what>, ceiling: <limit>, trigger: <when>` above intentional shortcuts.

══════════════════════════════════════════════════════════════════

[If --no-trigger flag and nothing found:]
No untracked deferrals. All intentional shortcuts have stated exit conditions.
```

## Rules

- Read-only — never modify files
- Count is key: the number of NO-TRIGGER entries is the headline metric
- Do not evaluate whether the shortcuts are good or bad — just surface them
- If `ceiling:` is missing, output "unspecified" — the ceiling matters but its absence is less urgent than a missing trigger
- The `// manta-defer:` annotation is for intentional, reviewed shortcuts — not for hiding real bugs or TODOs
