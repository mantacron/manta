---
name: rpi:research
description: RPI Step 2 — Research and analyze a feature for GO/NO-GO. Runs 6 agents in sequence (requirement-parser → product-manager → Explore → senior-software-engineer → constitutional-validator → technical-cto-advisor) and writes rpi/{slug}/research/RESEARCH.md.
argument-hint: "<feature-slug>"
---

**Begin by outputting:** `[ Manta Enterprise — RPI: Research ]`

# RPI: Research

**RPI Step 2 of 4**: Research & GO/NO-GO Gate

This command prevents wasted implementation effort by running a structured multi-agent analysis before any code is written.

**Prerequisites:**
- Feature folder exists: `rpi/{slug}/`
- Feature request file exists: `rpi/{slug}/REQUEST.md`

**Output:** `rpi/{slug}/research/RESEARCH.md` with a GO | CONDITIONAL GO | DEFER | NO-GO verdict.

---

## Step 0 — Parse Input & Validate

Extract the feature slug from `$ARGUMENTS`. The user may pass just the slug (`oauth2`) or the full path (`rpi/oauth2/REQUEST.md`) — normalize to the slug.

```bash
FEATURE_SLUG="$ARGUMENTS"
# Strip rpi/ prefix and /REQUEST.md suffix if present
FEATURE_SLUG=$(echo "$FEATURE_SLUG" | sed 's|^rpi/||;s|/REQUEST\.md$||')

echo "Feature slug: $FEATURE_SLUG"

# Validate
if [ ! -d "rpi/$FEATURE_SLUG" ]; then
  echo "ERROR: rpi/$FEATURE_SLUG/ not found."
  echo "Create the feature folder first:"
  echo "  mkdir -p rpi/$FEATURE_SLUG"
  echo "  # Write your feature description to rpi/$FEATURE_SLUG/REQUEST.md"
  exit 1
fi

if [ ! -f "rpi/$FEATURE_SLUG/REQUEST.md" ]; then
  echo "ERROR: rpi/$FEATURE_SLUG/REQUEST.md not found."
  echo "Write your feature description to REQUEST.md first."
  exit 1
fi

cat "rpi/$FEATURE_SLUG/REQUEST.md"
```

Also detect subdirectory mode:
```bash
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
CATHY_DIR=$(pwd)
[ "$GIT_ROOT" != "$CATHY_DIR" ] && PREFIX="../" || PREFIX=""
```

---

## Step 1 — Parse Requirements

**Agent:** `requirement-parser`

Invoke with the REQUEST.md content. The agent extracts structured requirements, flags clarifying questions, and estimates complexity.

**If the requirement-parser returns CLARIFYING QUESTIONS that are blockers**, stop and present them to the user before continuing. Wait for answers before proceeding.

---

## Step 2 — Product Analysis

**Agent:** `product-manager`

Pass the structured requirements from Step 1. The agent assesses user value, strategic alignment, and constitution compliance.

---

## Step 3 — Codebase Exploration

**Agent:** `Explore` (built-in, subagent_type: "Explore")

Explore the codebase to understand what already exists for the feature's target component. Pass the target component(s) from Step 1. Use "thorough" search breadth.

The agent should find:
- Existing code that's relevant or must change
- Current data models in the affected area
- Integration points the feature will touch
- Existing patterns to follow or extend

---

## Step 4 — Technical Feasibility

**Agent:** `senior-software-engineer`

Pass: structured requirements, product analysis, and the Explore findings. The agent assesses technical feasibility, recommends an approach, and estimates effort.

---

## Step 5 — Constitutional Validation

**Agent:** `constitutional-validator`

Pass: feature description, technical approach, and any AI/data concerns surfaced in Steps 2–4. The agent checks mission alignment, human oversight, privacy, architectural integrity, and AI ethics.

---

## Step 6 — CTO Recommendation

**Agent:** `technical-cto-advisor`

Pass: all previous agent outputs. The agent synthesizes everything into a single GO/NO-GO decision with rationale and conditions.

---

## Step 7 — Write Research Report

**Agent:** `documentation-analyst-writer`

Pass: all phase outputs. The agent writes the complete research report to:
```
rpi/{slug}/research/RESEARCH.md
```

Create the directory first:
```bash
mkdir -p "rpi/$FEATURE_SLUG/research"
```

---

## Completion Output

After all agents complete, report:

```
RPI Research Complete — rpi/{slug}/research/RESEARCH.md

Decision: GO | CONDITIONAL GO | DEFER | NO-GO
Confidence: High | Medium | Low

Summary: {one sentence rationale}

Scores:
  Product Viability:      High | Medium | Low
  Technical Feasibility:  High | Medium | Low
  Constitutional:         PASS | WARN | FAIL

Next steps:
  GO/CONDITIONAL GO → /project:rpi:plan {slug}
  DEFER/NO-GO       → Review rpi/{slug}/research/RESEARCH.md for rationale
```

**After completing, suggest:**
> This research workflow consumed significant context. Consider running `/compact` before proceeding to planning.
