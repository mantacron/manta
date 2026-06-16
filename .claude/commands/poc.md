**Begin by outputting:** `[ Manta — POC Init ]`

Fast-track initialization for proofs of concept and quick experiments.
No spec interview. No risk register. No architecture phases.
Three questions → project skeleton → start coding in under 5 minutes.

---

## What This Does

`/project:poc` is a stripped-down init for projects where the goal is to move fast
and validate an idea — not ship production software yet.

It generates the minimum needed to start coding with the review pipeline active:
- Lightweight `spec/SPEC.md` (4 sections — enough for agents to know what you're building)
- `.env.example` (stack-appropriate basics)
- `.gitignore` (stack-appropriate)
- `README.md` (one-pager: what it is + how to run)
- Minimal directory structure
- Git hooks (pre-commit still runs — quality still matters)

Everything skipped that full `/project:init` does:
- Phase-by-phase interview
- `ARCHITECTURE.md` (skip)
- `RISKS.md` (skip)
- `CONSTITUTION.md` (skip)
- Pattern configuration (skip — add later with `/project:capture-patterns`)
- CI/CD template (skip)

When your POC graduates to production: run `/project:init` — it detects the existing spec
and offers a targeted update session rather than starting over.

---

## Step 1: Three Questions

Ask all three at once in a single message:

> "Three quick questions and we'll have you set up:
>
> 1. **What is this POC called, and what does it do?** (One sentence is fine)
> 2. **What are the 2-3 main things it needs to do?** (Not a full spec — just enough so the review agents know what's in scope)
> 3. **Stack preference?** If you have one, name it. If not, tell me the language and I'll pick the framework."

Wait for answers. Do not ask follow-up questions. Work with what you get.
If any answer is too vague to name a stack, default to: **TypeScript + Express + PostgreSQL**.

---

## Step 2: Confirm Stack in One Message

Based on the answers, pick a stack and confirm it in one shot:

> "Got it. I'll use: **[Language] + [Framework] + [DB if any]**
>
> Starting setup now — I'll write 4 files and create the directory structure, then commit."

Do not wait for confirmation unless the stack choice is genuinely ambiguous. Move fast.

### Stack Defaults

| Signal | Stack |
|---|---|
| "TypeScript" / "JS" / "Node" / no preference | TypeScript + Express + PostgreSQL |
| "Python" | Python + FastAPI |
| "Go" / "golang" | Go + chi |
| "React" / "Next" / "frontend" | Next.js 15 + TypeScript |
| "CLI" | Go or Python (pick based on complexity) |
| "script" / "automation" | Python |
| "mobile backend" / "lightweight API" | TypeScript + Hono on Bun |

---

## Step 3: Generate Artifacts

Write all files without previewing each one. Generate them in order:

### 3.1 — spec/SPEC.md (lightweight)

Four sections only:

```markdown
# [Project Name] — POC Spec

> **Status: POC** — This is a proof of concept. Run `/project:init` to promote to a full spec.
> Generated: [date]

## 1. Overview

**What**: [one paragraph description from the interview]
**Why**: POC to validate [core hypothesis or idea]
**Who**: [who will use or test this]

## 2. In Scope (for this POC)

- [feature 1]
- [feature 2]
- [feature 3 if given]

## 3. Out of Scope (for this POC)

- Production auth
- Rate limiting
- Multi-tenant support
- Performance optimization
- Full test coverage

_Add anything explicitly excluded by the developer here._

## 4. Stack

- **Language**: [language]
- **Framework**: [framework]
- **Database**: [db or "none / in-memory"]
- **Package manager**: [npm / pnpm / pip / go mod / etc.]
```

Create the `spec/` directory if it doesn't exist.

### 3.2 — README.md

```markdown
# [Project Name]

[One-sentence description]

## What This Does

[2-3 sentences from the overview]

## Setup

\`\`\`bash
[install command for the stack]
cp .env.example .env
# Edit .env with your values
[run command for the stack]
\`\`\`

## POC Status

This is a proof of concept. See `spec/SPEC.md` for what's in scope.
```

### 3.3 — .env.example

Generate based on the detected stack with only the variables actually needed:

- **TypeScript/Node**: `DATABASE_URL=`, `PORT=3000`, `NODE_ENV=development`
- **FastAPI**: `DATABASE_URL=`, `PORT=8000`
- **Go**: `DATABASE_URL=`, `PORT=8080`
- **Next.js**: `NEXTAUTH_SECRET=`, `DATABASE_URL=`, `NEXTAUTH_URL=http://localhost:3000`
- **No DB**: `PORT=`, `NODE_ENV=development`

Do not add variables that aren't needed. Three to five lines is fine.

### 3.4 — .gitignore

Use a tight, stack-appropriate gitignore. Include at minimum:
- `.env` (always)
- Language build artifacts (`dist/`, `__pycache__/`, `target/`, `*.pyc`)
- Package directories (`node_modules/`, `vendor/`)
- IDE files (`.idea/`, `.vscode/`)
- OS files (`.DS_Store`, `Thumbs.db`)
- Test coverage output (`coverage/`, `.nyc_output/`)

### 3.5 — Directory Structure

Create a minimal but correct directory structure for the stack. Keep it flat — POCs don't need deep module hierarchies.

**TypeScript/Node API:**
```
src/
  routes/
  middleware/
  db/
tests/
```

**FastAPI:**
```
app/
  routers/
  models/
  db/
tests/
```

**Go:**
```
cmd/
  main.go
internal/
  handlers/
  models/
```

**Next.js:**
```
app/
  (routes here via App Router)
components/
lib/
```

Create placeholder files (`README.md` or `index.ts`/`__init__.py` as appropriate) in each directory so git tracks them.

---

## Step 4: Run Setup

```bash
bash scripts/setup.sh
```

If setup.sh fails, diagnose and fix before proceeding.

---

## Step 5: First Commit

Stage and commit everything:

```bash
git add spec/ README.md .env.example .gitignore src/ tests/ app/ cmd/ internal/ components/ lib/
```

Commit with:
```
chore: poc init — [Project Name]

- Lightweight spec (4 sections)
- [Stack] project structure
- Git hooks active
```

Do not push.

---

## Step 6: Handoff

Print this (fill in the brackets):

```
[ Manta — POC Init Complete ]
────────────────────────────────────────────────────────────────────────
Project:   [name]
Stack:     [stack]
Spec:      spec/SPEC.md  (4-section POC spec)
Hooks:     pre-commit active — agents review every commit

Start coding. Run /project:write "[feature]" to generate your first endpoint.

When this POC is ready to become a real project:
  → /project:init   (detects existing spec, runs targeted update session)
────────────────────────────────────────────────────────────────────────
```

---

## Rules

- **Ask exactly three questions, once** — do not extend the interview
- **Do not generate ARCHITECTURE.md, RISKS.md, or CONSTITUTION.md** — these come with `/project:init`
- **Do not ask for per-file confirmation** — write all files, then show the summary
- **Do not suggest CI/CD** — out of scope for POC init
- **Do not run `/project:capture-patterns`** — nothing to scan yet
- **Speed is the feature** — if something is unclear, make a reasonable default and note it in the output
