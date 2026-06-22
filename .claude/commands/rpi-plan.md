---
name: rpi:plan
description: RPI Step 3 — Generate comprehensive planning documentation for a feature that received a GO. Produces pm.md (product requirements), ux.md (UX design), eng.md (engineering spec), and PLAN.md (phased implementation roadmap).
argument-hint: "<feature-slug>"
---

**Begin by outputting:** `[ Manta Enterprise — RPI: Plan ]`

# RPI: Plan

**RPI Step 3 of 4**: Planning & Specification

Turns a GO research verdict into complete, implementation-ready documentation. No code is written here — only specs.

**Prerequisites:**
- `rpi/{slug}/research/RESEARCH.md` exists with GO or CONDITIONAL GO verdict

**Output:**
```
rpi/{slug}/plan/
  pm.md       ← Product requirements & user stories
  ux.md       ← UX design & interaction flows
  eng.md      ← Engineering architecture & spec
  PLAN.md     ← Phased implementation roadmap with gates
```

---

## Step 0 — Parse Input & Validate

```bash
FEATURE_SLUG=$(echo "$ARGUMENTS" | sed 's|^rpi/||;s|/.*||')

echo "Planning feature: $FEATURE_SLUG"

if [ ! -f "rpi/$FEATURE_SLUG/research/RESEARCH.md" ]; then
  echo "ERROR: Research report not found at rpi/$FEATURE_SLUG/research/RESEARCH.md"
  echo "Run /project:rpi:research $FEATURE_SLUG first."
  exit 1
fi

# Check verdict
VERDICT=$(grep -i "^\*\*Decision:\*\*\|^Decision:" "rpi/$FEATURE_SLUG/research/RESEARCH.md" | head -1)
echo "Research verdict: $VERDICT"
```

If the verdict is NO-GO, warn the user and ask for confirmation before continuing. If DEFER, stop and explain.

---

## Step 1 — Load Research Context

Read the full research report and extract:
- Feature name, type, target components
- Complexity estimate and effort
- Recommended technical approach
- Key constraints and risks
- Constitutional conditions (if CONDITIONAL GO)

```bash
cat "rpi/$FEATURE_SLUG/research/RESEARCH.md"
cat "rpi/$FEATURE_SLUG/REQUEST.md"
```

---

## Step 2 — Product Requirements (pm.md)

**Agent:** `product-manager`

Pass: research findings. The agent produces:
- User stories with role/action/benefit format
- Acceptance criteria per story
- Success metrics
- Explicit out-of-scope items

The `documentation-analyst-writer` writes the output to `rpi/{slug}/plan/pm.md`.

---

## Step 3 — UX Design (ux.md)

**Agent:** `ux-planner`

Pass: requirements, research findings, and existing UI patterns discovered in research.

The agent produces:
- User journey map
- Screen / component inventory
- Interaction states per component
- Navigation and information architecture
- Accessibility requirements
- Edge cases

If the feature has no user-facing surface (pure backend/API), the agent writes `UX SCOPE: None` and this step is marked complete.

The `documentation-analyst-writer` writes to `rpi/{slug}/plan/ux.md`.

---

## Step 4 — Engineering Specification (eng.md)

**Agent:** `senior-software-engineer`

Pass: research findings (including codebase discovery), pm.md content, ux.md content.

The agent produces:
- Architecture design (components, data flows, integration points)
- Data model changes
- API contract
- Phased implementation breakdown with effort per phase
- Security and performance considerations
- Testing requirements
- Deployment notes

The `documentation-analyst-writer` writes to `rpi/{slug}/plan/eng.md`.

---

## Step 5 — Constitutional Pre-Check

**Agent:** `constitutional-validator`

Pass: pm.md, ux.md, eng.md. Validate the plan (not just the feature request) against the constitution. Plans sometimes introduce implementation details that weren't in the original request — this catches them early.

If FAIL findings are reported, the plan must be revised before proceeding to implement.

---

## Step 6 — Implementation Roadmap (PLAN.md)

**Agent:** `documentation-analyst-writer`

Synthesize pm.md, ux.md, eng.md, and the constitutional validation into the final PLAN.md:

- Summary table of phases with effort and gates
- Detailed task list per phase
- Validation gate commands per phase
- Risk and dependency table
- Definition of done for the full feature

Write to `rpi/{slug}/plan/PLAN.md`.

Create the directory first:
```bash
mkdir -p "rpi/$FEATURE_SLUG/plan"
```

---

## Completion Output

```
RPI Plan Complete — rpi/{slug}/plan/

Files written:
  rpi/{slug}/plan/pm.md       ← Product requirements
  rpi/{slug}/plan/ux.md       ← UX design (or: N/A — no UI surface)
  rpi/{slug}/plan/eng.md      ← Engineering spec
  rpi/{slug}/plan/PLAN.md     ← Phased implementation roadmap

Constitutional Pre-Check: PASS | WARN | FAIL
Phases: {N} phases, estimated effort: {Small/Medium/Large/Epic}

Next step:
  /project:rpi:implement {slug}
```

**After completing, suggest:**
> Consider running `/compact` before starting implementation.
