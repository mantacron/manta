---
name: rpi:implement
description: RPI Step 4 — Execute phased implementation with validation gates. Reads PLAN.md and eng.md, implements phase-by-phase, runs test gates after each phase, and writes an IMPLEMENT.md record.
argument-hint: "<feature-slug> [--phase N]"
---

**Begin by outputting:** `[ Manta Enterprise — RPI: Implement ]`

# RPI: Implement

**RPI Step 4 of 4**: Implementation

Executes the implementation plan phase-by-phase with mandatory validation gates. Does not proceed to the next phase if the current one fails its gate.

**Prerequisites:**
- `rpi/{slug}/plan/PLAN.md` exists
- `rpi/{slug}/plan/eng.md` exists

**Flags:**
- `--phase N` — start from a specific phase (useful for resuming after a partial run)
- `--validate-only` — run the validation gate for the current phase without implementing

---

## Step 0 — Parse Input & Load Plan

```bash
# Parse args
FEATURE_SLUG=$(echo "$ARGUMENTS" | sed 's/ .*//' | sed 's|^rpi/||;s|/.*||')
START_PHASE=$(echo "$ARGUMENTS" | grep -oE '\-\-phase [0-9]+' | grep -oE '[0-9]+' || echo "1")
VALIDATE_ONLY=$(echo "$ARGUMENTS" | grep -q '\-\-validate-only' && echo "true" || echo "false")

echo "Implementing: $FEATURE_SLUG (from Phase $START_PHASE)"

# Validate
if [ ! -f "rpi/$FEATURE_SLUG/plan/PLAN.md" ]; then
  echo "ERROR: rpi/$FEATURE_SLUG/plan/PLAN.md not found."
  echo "Run /project:rpi:plan $FEATURE_SLUG first."
  exit 1
fi

# Load the plan
cat "rpi/$FEATURE_SLUG/plan/PLAN.md"
cat "rpi/$FEATURE_SLUG/plan/eng.md"
cat "rpi/$FEATURE_SLUG/research/RESEARCH.md" 2>/dev/null | head -60 || true
```

---

## Step 1 — Pre-Implementation Constitutional Check

**Agent:** `constitutional-validator`

Before writing any code, run a final constitutional check. The research-phase validation was on the proposal; this check is on the actual plan with full implementation detail.

If the validator returns FAIL, stop and report the blocking findings before proceeding.

---

## Step 2 — Execute Phases

For each phase in PLAN.md (starting from `$START_PHASE`):

### Phase Loop

**Agent:** `senior-software-engineer`

Pass:
- The full plan context (PLAN.md + eng.md)
- The current phase number and description
- The previous phase gate results (if applicable)

The agent:
1. Re-reads relevant files before editing any of them
2. Implements all tasks in the current phase
3. Follows existing code patterns and conventions
4. Writes complete, production-ready code (no TODOs, no stubs)

### Validation Gate (after each phase)

Run the gate command from PLAN.md for this phase:

```bash
# The gate command is defined per-phase in PLAN.md
# Example gate — adapt to project's actual test command:
if [ -f package.json ]; then
  npm test 2>&1 | tail -30
elif [ -f go.mod ]; then
  go test ./... 2>&1 | tail -30
elif [ -f pyproject.toml ] || [ -f requirements.txt ]; then
  python -m pytest 2>&1 | tail -30
elif [ -f Cargo.toml ]; then
  cargo test 2>&1 | tail -30
fi
```

**Gate result:**
- `PASS` — proceed to next phase
- `FAIL` — stop. Report the failure. Do not proceed until fixed. The `senior-software-engineer` agent should fix the failure before re-running the gate.
- `SKIP` — tests not available; proceed with manual verification note

---

## Step 3 — Post-Implementation Review

After all phases complete, run the `code-quality` agent on the changed files:

```bash
git diff HEAD --name-only 2>/dev/null | head -20
```

Pass the list of changed files to `code-quality`. Address any CRITICAL or WARNING findings before declaring the implementation complete.

---

## Step 4 — Write Implementation Record

**Agent:** `documentation-analyst-writer`

Write `rpi/{slug}/implement/IMPLEMENT.md` with:
- Phase-by-phase status (PASS/FAIL/PARTIAL)
- Files changed per phase
- Test results per phase
- Any notes or deviations from the plan

```bash
mkdir -p "rpi/$FEATURE_SLUG/implement"
```

---

## Completion Output

```
RPI Implementation Complete — {slug}

Phases completed: {N}/{total}
Phase results:
  Phase 1 — {name}: PASS
  Phase 2 — {name}: PASS
  ...

Code quality: PASS | {N} warnings

Files changed: {count}
Implementation record: rpi/{slug}/implement/IMPLEMENT.md

Next steps:
  1. Review changes: git diff HEAD
  2. Create a PR: gh pr create
  3. Update docs if needed: /project:update-docs
```

---

## Error Handling

**If a phase gate FAILS:**
- Report the failure clearly
- Have `senior-software-engineer` diagnose and fix it
- Re-run the gate
- If gate fails twice, surface for human decision (do not loop indefinitely)

**If constitutional-validator returns FAIL:**
- Stop immediately
- Report the blocking findings with specific changes required
- Do not proceed until the plan is revised and re-validated

**If tests are missing:**
- Issue a WARNING: "No tests exist for this phase's changes — gate SKIPPED"
- Recommend: "Consider running /project:generate-tests after implementation"
