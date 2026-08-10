# Manta — Developer User Guide

A practical guide to using Manta day to day. Commands are ordered roughly by when
you'll first reach for them, not alphabetically.

New here? Read **Install**, then jump to whichever **Getting Started** path
matches your situation. Everything after that is reference.

- [Install](#install)
- [Getting Started: New Project](#getting-started-new-project)
- [Getting Started: Existing Codebase](#getting-started-existing-codebase)
- [The Daily Loop](#the-daily-loop)
- [Command Reference](#command-reference) — by stage
- [Controlling Cost and Depth](#controlling-cost-and-depth)
- [Suppressing Findings](#suppressing-findings)
- [Troubleshooting](#troubleshooting)
- [Cheat Sheet](#cheat-sheet)

---

## Install

```bash
bash scripts/install.sh
```

Installs the agents, commands, and git hooks. Safe to re-run.

Already have a project and only want the commit/push gates?

```bash
bash scripts/setup.sh      # configures git hooks only, no wizard
```

**Requirements.** One AI CLI on your `PATH` — `claude` (recommended), `codex`, or
`gemini`. The hooks auto-detect; override with `AI_BIN=gemini git commit`.

**Installed as a subfolder?** If Manta lives inside a larger project (e.g.
`my-app/manta/`), every agent automatically targets the parent directory for
project files. Nothing to configure.

---

## Getting Started: New Project

You have an idea and an empty (or nearly empty) directory.

### 1. Run the wizard

```
/init
```

Walks you through spec creation, stack selection, and scaffolding in one
conversation.

> **In a hurry?** Use `/poc` instead. Three questions, then a lightweight spec
> and skeleton — no interview. Good for spikes and demos.

### 2. Build your first feature

For anything non-trivial, use the RPI workflow — it catches bad ideas before you
write code:

```bash
mkdir -p rpi/user-notifications
# Write rpi/user-notifications/REQUEST.md in plain English:
#   What is the feature? Who needs it? What problem does it solve?
#   Any constraints — performance, security, integrations?
```

```
/rpi-research user-notifications    # GO / NO-GO gate
/rpi-plan user-notifications        # pm.md, ux.md, eng.md, PLAN.md
/rpi-implement user-notifications   # phased build with validation gates
```

For something small and obvious, skip RPI:

```
/write "POST /api/subscribe endpoint with email validation and rate limiting"
```

### 3. Commit

```bash
git add . && git commit -m "feat: subscribe endpoint"
```

The pre-commit hook fires automatically. See [The Daily Loop](#the-daily-loop).

---

## Getting Started: Existing Codebase

You've inherited or joined a project and want Manta protecting it.

### 1. Get oriented

```
/explain src/payments/checkout.ts
```

Plain-language explanation of any file, function, module, or flow — including who
calls it, what it depends on, and where it sits architecturally.

```
/blueprint
```

Generates `docs/BLUEPRINT.md`: stack, API inventory, ER diagram, module map. A
living map that stays useful long after onboarding.

### 2. Establish a baseline

```
/audit
```

Full codebase audit producing `reports/YYYY-MM-DD-report.md` with a health score,
findings, and quick wins. This is your baseline — future audits show trends
against it.

### 3. Teach Manta your conventions

```
/capture-patterns
```

Scans the codebase and writes `PATTERNS.md` (human-readable) plus
`manta.patterns.json` (what agents actually read). Commit both — now the whole
team is held to the same conventions at every commit.

### 4. Deal with the backlog

A first audit on a mature codebase often returns a lot. Don't try to fix it all:

```
/fix                    # suggestions for the CRITICAL findings
/fix --apply            # walk through each fix with Y/n, writes to files
```

For findings that are intentional trade-offs, record them rather than fixing
them — see [Suppressing Findings](#suppressing-findings).

---

## The Daily Loop

This is what using Manta actually feels like once it's set up. Most of it is
automatic.

```
   write code
       ↓
   git commit ──────► pre-commit hook: 4 agents review staged changes
       ↓                 security-sentinel · code-quality
       │                 perf-analyzer · db-migration-guardian (if migrations)
       │
       ├── CRITICAL? ──► COMMIT BLOCKED  →  run /fix
       ├── WARNING?  ──► commit allowed, shown prominently (will block push)
       └── clean     ──► commit proceeds
       ↓
   git push ────────► pre-push hook: 3–4 agents on the branch diff
       ↓                 db-migration-guardian is trigger-routed —
       │                 it skips when no migration files changed
       │
       ├── CRITICAL or WARNING? ──► PUSH BLOCKED  →  run /fix
       └── clean                ──► push proceeds
```

**Severity rules:**

| Level | Blocks commit | Blocks push |
|-------|:-------------:|:-----------:|
| `CRITICAL` — security risk, broken logic | yes | yes |
| `WARNING` — code smell, quality issue | no (shown) | yes |
| `INFO` — optional improvement | no | no |

Warnings are deliberately asymmetric: they don't interrupt your commit rhythm,
but they won't reach the shared branch unaddressed.

---

## Command Reference

Grouped by when you use them.

### Stage 1 — Starting out

#### `/init`
Setup wizard — new project or existing codebase. **Start here.**
```
/init
```

#### `/poc`
Fast POC setup — 3 questions, lightweight spec, project skeleton.
```
/poc
```

---

### Stage 2 — Understanding the code

#### `/explain [target]`
Plain-language explanation of a file, function, module, or flow — with callers,
dependencies, and execution path.
```
/explain src/auth/session.ts
/explain "how does a request get authenticated"
```

#### `/blueprint`
Generates `docs/BLUEPRINT.md` — stack, architecture, API inventory, ER diagram,
module map.
```
/blueprint
```

#### `/wiki [--url=URL]`
Generates a product wiki in `docs/wiki/` — route discovery, screenshots, feature
analysis.
```
/wiki
/wiki --url=http://localhost:3000
```

---

### Stage 3 — Building

#### `/scaffold "description"`
Generates boilerplate matching your project's conventions. Leaves `TODO` markers
where business logic goes.
```
/scaffold "invoice export endpoint"
```

#### `/write "description"`
Generates a complete, production-ready implementation — no TODOs. Rate limiting,
auth wiring, validation, pagination, transactions, and audit trail applied
automatically.
```
/write "POST /api/invoices with pagination, RBAC, and idempotency keys"
```

> **`/scaffold` or `/write`?** Use `/scaffold` when you want to control the
> implementation yourself; `/write` when you want production-ready code fast.
> When in doubt, use `/write`. Run `/review` after either.

#### `/ui [path or description]`
Converts designs — screenshots, Figma exports, wireframes — into responsive,
accessible components. Reads `ui-designs/` by default.
```
/ui
/ui ui-designs/settings-page.png
```

---

### Stage 4 — The feature workflow (RPI)

Research → Plan → Implement, with GO/NO-GO gates.

```
Step 1  mkdir -p rpi/{slug} && write rpi/{slug}/REQUEST.md
Step 2  /rpi-research {slug}     → research/RESEARCH.md   (GO/NO-GO gate)
Step 3  /rpi-plan {slug}         → plan/pm.md, ux.md, eng.md, PLAN.md
Step 4  /rpi-implement {slug}    → implement/IMPLEMENT.md
```

#### `/rpi-research <slug>`
Multi-agent GO / CONDITIONAL GO / DEFER / NO-GO decision with a confidence score.
```
/rpi-research user-notifications
```

#### `/rpi-plan <slug>`
Product requirements, UX design, engineering spec, and a phased roadmap.
```
/rpi-plan user-notifications
```

#### `/rpi-implement <slug>`
Executes the plan phase by phase, with a validation gate after each phase.
```
/rpi-implement user-notifications
```

---

### Stage 5 — Review and fix

The hooks run these automatically. You invoke them by hand for a review outside
the git flow.

#### `/review`
Full interactive review of staged changes, consolidated report saved to
`reports/`.
```
/review
/review --depth=deep
```

#### `/fix [--apply]`
Concrete fix suggestions for the last blocked commit. Reads only the flagged
files. `--apply` walks each fix with Y/n and writes to disk.
```
/fix
/fix --apply
```

#### `/generate-tests [file]`
Interactive test generation for uncovered code.
```
/generate-tests
/generate-tests src/billing/proration.ts
```

#### `/pre-commit-review` · `/pre-push-review`
Machine-readable output for the git hooks. **Not normally run by hand.**

---

### Stage 6 — Auditing

#### `/audit [focus] [--depth=...]`
Full codebase audit → `reports/YYYY-MM-DD-report.md` with score, trends,
findings, and quick wins. Focus flags: `security`, `quality`, `performance`.
```
/audit
/audit security
/audit --depth=quick          # fast triage
/audit --depth=deep           # release gate
```

#### `/security-scan`
Full security audit of the repository — secrets and OWASP Top 10.
```
/security-scan
```

#### `/debt`
Harvests `// manta-defer:` annotations into a ledger and flags any deferral with
no exit trigger.
```
/debt
```

---

### Stage 7 — Housekeeping

#### `/update-docs`
Updates `README.md` and appends structured entries to `CHANGELOG.md`.
```
/update-docs
```

#### `/capture-patterns`
Scans the codebase and regenerates `PATTERNS.md` + `manta.patterns.json`.
```
/capture-patterns
```

---

## Controlling Cost and Depth

Manta spawns multiple agents per review, so it's worth knowing the levers.

### Depth

`/audit` and `/review` accept `--depth`:

| Depth | Reads per agent | Findings | Severities | Use when |
|-------|-----------------|----------|------------|----------|
| `quick` | ≤5, grep-first | top 5 per severity | CRITICAL only | Triage, large repos |
| `standard` *(default)* | ≤15 | top 10 per severity | CRITICAL + WARNING | Routine use |
| `deep` | ≤50, cross-file data flow | all, untruncated | CRITICAL + WARNING + INFO | Release gates |

Depth changes how hard each agent works — not which agents run.

### Models

Agents declare their model in frontmatter. `security-sentinel`, `code-quality`,
and `review-reporter` run on Opus — taint analysis, false-positive
discrimination, and verdict logic are where being wrong is expensive. The rest of
the review and planning agents run on Sonnet. The agents that produce artifacts
you keep (`code-writer`, `scaffolding-agent`, `ui-component-writer`,
`wiki-agent`) inherit whatever model you're running.

The git hooks pass `--model "${MANTA_MODEL:-sonnet}"`, which sets the
**orchestrator's** model; unpinned agents inherit it. Override per run:

```bash
MANTA_MODEL=opus git push
```

### Timeouts

```bash
export CLAUDE_HOOK_TIMEOUT=180        # commit review budget (default 120s)
export CLAUDE_PUSH_HOOK_TIMEOUT=300   # push review budget (default 240s)
```

Reviews **fail closed**: a review that times out or errors blocks the commit
rather than waving it through.

---

## Suppressing Findings

Three levels, from broadest to narrowest.

**1. File-level — `.mantaignore` in the project root:**

```
# Suppress MD5 findings in hash utility (non-security use)
src/utils/hash.ts  MD5

# Suppress DRY warnings in generated code
src/generated/**   DRY

# Suppress all INFO findings globally
**                 INFO
```

Format: `[file-glob]  [keyword-or-severity]  # optional reason`

**2. Line-level — inline annotation:**

```typescript
const hash = md5(data); // manta-ignore: non-security hash for cache key
```

Use `#` for Python and shell. Always include a reason — a suppression without one
is itself flagged as a WARNING.

**3. Deferrals — record a shortcut instead of hiding it:**

```typescript
// manta-defer: in-memory cache, ceiling: >100 concurrent users, trigger: load test p95 > 200ms
const cache = new Map();
```

Run `/debt` to harvest these into a ledger.

> Suppressions are for intentional trade-offs, accepted risk, and false
> positives — not for hiding real issues.

---

## Troubleshooting

**Commit blocked and I need to ship right now.**
```bash
SKIP_CLAUDE_REVIEW=1 git commit -m "hotfix: ..."
SKIP_CLAUDE_PUSH_REVIEW=1 git push
```
Both are logged to `reports/.bypass-log`. Emergency use only.

**"Review timed out — commit BLOCKED."**
The review didn't finish, so it can't vouch for the commit. Raise the budget with
`CLAUDE_HOOK_TIMEOUT=180`, or bypass explicitly as above.

**"No AI CLI found — skipping review."**
Install one: `npm i -g @anthropic-ai/claude-code`. Or point at another with
`AI_BIN=gemini`.

**Reviews feel slow or expensive.**
Check that `.mantaignore` covers your generated code, run `/capture-patterns` so
agents stop flagging your conventions, and use `--depth=quick` for routine
sweeps.

**Commit only touches docs — why did it still review?**
It shouldn't. The hook skips entirely when no code files are staged.

---

## Cheat Sheet

```
SETUP           /init            wizard — new project or existing codebase
                /poc             3 questions → spec + skeleton

UNDERSTAND      /explain <x>     plain-language explanation of any code
                /blueprint       living project map → docs/BLUEPRINT.md
                /wiki            product wiki → docs/wiki/

BUILD           /scaffold "..."  boilerplate with TODOs
                /write "..."     complete production implementation
                /ui              designs → components

FEATURE (RPI)   /rpi-research    GO/NO-GO gate
                /rpi-plan        pm · ux · eng · PLAN
                /rpi-implement   phased build with gates

REVIEW          /review          full review of staged changes
                /fix [--apply]   fix suggestions for last block
                /generate-tests  tests for uncovered code

AUDIT           /audit [focus]   scored report + trends
                /security-scan   full security audit
                /debt            deferral ledger

HOUSEKEEPING    /update-docs     README + CHANGELOG
                /capture-patterns  regenerate conventions

ESCAPE HATCHES  SKIP_CLAUDE_REVIEW=1 git commit        (logged)
                SKIP_CLAUDE_PUSH_REVIEW=1 git push     (logged)
                MANTA_MODEL=opus git push
                CLAUDE_HOOK_TIMEOUT=180
                --depth=quick|standard|deep
```
