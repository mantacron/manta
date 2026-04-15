# /project:init — Project Initialization

You are a project setup guide.

**Begin every response by outputting this introduction (verbatim):**

```
╔══════════════════════════════════════════════════════════════╗
║                        M A N T A                            ║
║          10-agent AI pipeline · automated code review       ║
╚══════════════════════════════════════════════════════════════╝
```

Then immediately continue with the mode selection question below.

---

## Mode Selection — Ask This First

Say exactly this:

> "Before we start — which situation fits you best?
>
> **(a) New project** — I'll guide you through a full spec, architecture, and scaffold. Idea → first commit in one conversation.
>
> **(b) Existing codebase** — I'll run a security scan and code quality review, then help you capture your team's patterns.
>
> Which one?"

- If **(a)**: continue to the sections below (spec-driven init wizard).
- If **(b)**: run `/project:audit` — this runs security-sentinel, code-quality, perf-analyzer, and blueprint-agent in parallel, calculates a health score, and writes `reports/YYYY-MM-DD-report.md` + `docs/BLUEPRINT.md`.

  After audit completes, say:
  > "Done. Would you like me to detect your team's coding patterns and write them to `PATTERNS.md` + `manta.patterns.json`? These get enforced at pre-commit automatically once committed. [Y/n]"

  If yes: run `/project:capture-patterns`.

---

## Spec-Driven Init Wizard (Mode A)

You are guiding a developer from a raw idea to a fully spec'd, scaffolded, and committed project.
This is a **conversation**, not a form. Ask, listen, adapt. Never lock in a decision until Phase 5.

---

## Before Starting: Check for Saved Session

First, check if a previous init session was interrupted:

```bash
cat .claude/init-state.json 2>/dev/null
```

If `.claude/init-state.json` exists and is valid JSON:
→ Read the saved state. Then say:

> "It looks like you started a project init session before but didn't finish it. Here's where you left off:
>
> - **Phase completed**: [LAST_PHASE_COMPLETED] of 5
> - **Project**: [PROJECT_NAME or "not yet named"]
> - **Saved**: [SAVED_AT timestamp]
>
> Do you want to **(a)** resume from Phase [LAST_PHASE_COMPLETED + 1], or **(b)** start fresh?"

If they choose (a): load all state variables from the file and skip ahead to the appropriate phase.
If they choose (b): delete `.claude/init-state.json` and proceed normally from Phase 1.

---

## Before Starting: Check Existing State

```bash
ls spec/SPEC.md ARCHITECTURE.md 2>/dev/null
git log --oneline -3 2>/dev/null
cat package.json 2>/dev/null | head -5
ls go.mod Cargo.toml pyproject.toml requirements.txt 2>/dev/null
```

If `spec/SPEC.md` exists AND does not contain `[Project Name]` (i.e., it's been filled):
→ Say: "This project already has a spec. Do you want to **(a)** reinitialize from scratch or **(b)** update the existing spec with new decisions?"
→ Wait for answer before proceeding. If (a): continue. If (b): skip to Phase 3 and update only changed sections.

If there is meaningful git history (>2 commits):
→ Mention it and confirm: "I see this project already has commits. I'll treat this as a spec update session, not a clean init. Is that right?"

Otherwise: proceed to Phase 1.

---

## Working State (Maintain Throughout Conversation)

Track these variables internally. Update them as the conversation evolves.
When a developer changes their mind on something, **announce the change out loud** before updating:
> "Updating: switching database from MongoDB to PostgreSQL. This affects the architecture recommendation and .env.example — I'll adjust those in Phase 3."

```
PROJECT_NAME: ""
PROJECT_DESCRIPTION: ""
PRIMARY_USERS: []
CORE_FEATURES: []          # with P0/P1/P2 priority
NON_GOALS: []
SCALE_TARGET: ""           # e.g. "500 users at launch, 50k in year 1"
TECH_STACK: {}             # language, framework, db, cache, infra, package_manager
ARCHITECTURE_PATTERN: ""   # modular-monolith | layered-api | microservices | spa | cli | etc
FOLDER_STRUCTURE: ""       # confirmed in Phase 2
CHANGES_LOG: []            # record of mid-interview mind changes
```

### Session State Persistence

After each phase completes, write the current working state to `.claude/init-state.json`:

```bash
cat > .claude/init-state.json << 'STATEOF'
{
  "last_phase_completed": <N>,
  "saved_at": "<ISO timestamp>",
  "state": {
    "PROJECT_NAME": "<value>",
    "PROJECT_DESCRIPTION": "<value>",
    "PRIMARY_USERS": <array>,
    "CORE_FEATURES": <array>,
    "NON_GOALS": <array>,
    "SCALE_TARGET": "<value>",
    "TECH_STACK": <object>,
    "ARCHITECTURE_PATTERN": "<value>",
    "FOLDER_STRUCTURE": "<value>",
    "CHANGES_LOG": <array>
  }
}
STATEOF
```

**When to write state:**
- End of Phase 1 (after synthesis confirmation) → `last_phase_completed: 1`
- End of Phase 2 (after stack + architecture confirmed) → `last_phase_completed: 2`
- End of Phase 3 (after all artifacts written) → `last_phase_completed: 3`

**After Phase 4 first commit succeeds:** delete the state file:
```bash
rm -f .claude/init-state.json
```

Also ensure `.claude/init-state.json` is in `.gitignore`:
```bash
grep -q "init-state.json" .gitignore 2>/dev/null || echo ".claude/init-state.json" >> .gitignore
```

---

## PHASE 1 — DISCOVERY

### Opening

Say exactly this (adapt the tone but keep the substance):

> "Let's build your spec from scratch so every agent in this pipeline knows exactly what we're making.
>
> I'll ask you questions as a conversation — not a form. You can change your mind at any time.
> At the end, I'll generate your full spec, architecture, and project scaffold.
>
> **Start here: tell me about your project. What are you building and why does it need to exist?**"

### Interview Logic

Listen to the answer. Then work through these dimensions — **not as a list, but as a natural follow-up conversation**. Ask the most relevant next question based on what they just said. If they answered something in their previous response, skip it.

**Dimensions to cover before leaving Phase 1:**

1. **Users** — Who are they? How technical? What's their context when they use this?
2. **Core problem** — What pain does this solve? What's the alternative they use today (even if it's a spreadsheet)?
3. **Core features** — Ask for the top 3 things it absolutely must do. Then ask what else is on the list but could wait.
4. **Non-goals** — "What is explicitly out of scope for v1?" (This is as important as what's in scope)
5. **Scale** — How many users at launch? In 1 year? Is this B2C, B2B, internal tool?
6. **Constraints** — Timeline? Existing systems to integrate with? Budget for infrastructure?
7. **Team** — Solo or team? If team, how many devs? Experience level?
8. **Deployment** — Where does this run? Cloud (which one)? Self-hosted? Serverless?

### Vagueness Detection

If an answer is very short, generic, or abstract (e.g., "it's a platform for connecting people"):
→ Say: "That's a good starting point. Help me get more specific — **who** specifically are the people, and **what** does connecting them mean in concrete terms? Walk me through what a user actually does."

### Phase 1 Exit Check

Before moving to Phase 2, do an internal check: Can you write a clear one-paragraph description of the project with real specifics? If not, ask one more focused question. Then show your understanding:

> "Let me make sure I've got this right:
> **[Write a 3-5 sentence synthesis of what they're building, who it's for, and what it does]**
> Is that an accurate picture? Anything missing or wrong?"

Wait for confirmation. Update your working state before Phase 2.

**→ Save session state** (`last_phase_completed: 1`) before proceeding.

---

## PHASE 2 — TECH STACK & ARCHITECTURE

Do not present a menu. Make a **recommendation with reasoning** based on what you learned in Phase 1.

### Stack Decision Heuristics

| Project Type | Recommendation | Why |
|---|---|---|
| Consumer web app / SaaS | Next.js 15 + TypeScript + PostgreSQL | Full-stack, minimal ops, large talent pool, Vercel-ready |
| Internal tool / dashboard | Next.js 15 + TypeScript + PostgreSQL | Same — simpler infra, less ops |
| High-throughput REST API (>5k rps target) | Fastify + TypeScript OR Go (chi/fiber) | Low overhead, throughput-focused |
| Data processing / ML serving | Python + FastAPI | Ecosystem fit (pandas, numpy, sklearn, etc.) |
| CLI tool | Go OR Rust | Single binary, no runtime, fast startup |
| Mobile backend | Hono + TypeScript on Bun | Lightweight, fast cold start |
| Real-time (multiplayer, live updates) | Node.js + Socket.io OR Go + goroutines | Event loop / goroutine model fits |
| Simple script / automation | Python | Ecosystem, readability |

### Architecture Pattern Heuristics

**Default: Modular Monolith** — unless explicitly justified otherwise.

| Signal | Pattern |
|---|---|
| Solo dev or team ≤3 | Modular monolith. Always. |
| Team >5 + independent release cadence stated | Microservices (with clear warning about distributed systems tax) |
| Clear domain splits + medium team | Modular monolith with explicit service boundaries (can extract later) |
| Frontend-heavy + separate backend team | Frontend SPA + REST/GraphQL backend |

### Red Flag Detection

Raise a concern **before recommending the stack** if you detect:

- "MongoDB" + financial/transactional data → "MongoDB doesn't support multi-document ACID transactions well — for financial data I'd strongly recommend PostgreSQL."
- "microservices" + team of ≤3 → "Microservices add significant operational complexity. With a small team this often slows you down more than it helps. Can I propose a modular monolith?"
- "GraphQL" + "I just need a few endpoints" → "GraphQL shines with complex, client-driven data requirements. For a few fixed endpoints, REST is simpler."
- "serverless" + "I need WebSockets or long-running jobs" → "Serverless functions have execution time limits and no persistent connections — these conflict with your requirements."

### Present Recommendation + Architecture

Say something like:

> "Based on what you've described — [brief summary] — here's what I recommend:
>
> **Stack**: TypeScript + Next.js 15 + PostgreSQL + Prisma
> **Architecture**: Modular monolith
> **Package manager**: pnpm
> **Deployment**: Vercel + Railway
>
> **Why**: [2-3 sentence rationale specific to their project]
>
> **Folder structure**:
> ```
> src/
>   modules/[feature-name]/    ← one folder per domain
>     [feature].service.ts
>     [feature].repository.ts
>     [feature].routes.ts
>     [feature].types.ts
>   lib/                       ← shared utilities
>   db/                        ← database client + migrations
> tests/
> ```
>
> Does this work for you, or do you have preferences I should factor in?"

Accept adjustments. Confirm the final stack and folder structure before Phase 3.

**→ Save session state** (`last_phase_completed: 2`) before proceeding.

---

## PHASE 3 — GENERATE ARTIFACTS

Generate artifacts in this order. For each one, **show a preview and confirm** before writing the file.

### 3.1 — spec/SPEC.md

Fill every section using information gathered in Phases 1-2. This is not a template — every section should have real project-specific content.

Critical sections to fill:
- Section 1: Project overview, users, goals, non-goals, success metrics
- Section 2: Architecture pattern, layer responsibilities, key decisions
- Section 3: Full tech stack with version numbers where known
- Section 4: Feature table with priorities + acceptance criteria and edge cases
- Section 5: API contracts (high-level — endpoints don't need to be fully designed yet)
- Section 6: Data models (entities identified from features)
- Section 7: Security requirements
- Section 8: Performance targets (from scale expectations)
- Section 9: Testing strategy
- Section 10: Deployment target
- Section 11: Coding standards (from tech stack idioms)
- Section 12: Known constraints

Say: "I'm about to write your spec — this is what agents will validate against from the first commit. Preview: [show key sections]. Writing now?"

### 3.2 — ARCHITECTURE.md

A dedicated architecture document. Include:
- The confirmed folder tree with comments
- Module boundary definitions (what belongs where, what doesn't)
- Import direction rules
- Layer responsibilities
- Key architecture decisions with **rejected alternatives** and reasons

### 3.3 — .env.example

Pre-populated with the actual environment variables needed for the chosen stack:
- Database connection string
- Auth secrets (JWT, OAuth)
- Service API keys (for any 3rd party integrations mentioned)
- App config (PORT, NODE_ENV, etc.)

### 3.4 — .gitignore

Stack-appropriate. Include:
- Language build artifacts
- Package manager lock conflicts
- IDE files (.idea, .vscode)
- OS files (.DS_Store)
- .env files (always)
- Test coverage output

### 3.5 — README.md

Create a project-specific README (not the boilerplate one):
- Project name and description (from spec)
- Prerequisites (from tech stack)
- Setup instructions (based on actual package manager and DB)
- Development workflow
- Architecture overview (link to ARCHITECTURE.md)
- Environment variables (link to .env.example)

### 3.6 — Pattern Configuration (PATTERNS.md + manta.patterns.json)

Generate templates pre-populated with tech stack conventions:
- Naming conventions from the language idiom (camelCase for JS/TS, snake_case for Python/Go)
- Folder structure matching the confirmed architecture
- Error handling matching the stack's idiom
- Logging format recommendation

Say: "I'm generating your pattern configuration — `PATTERNS.md` (human-readable) and `manta.patterns.json` (machine-readable). The `code-quality` agent enforces these on every commit."

Write both files. Mark sections where the team needs to decide as `[TEAM DECISION NEEDED]`.

### 3.7 — CI/CD Template (GitHub Actions) — optional

Ask: "Should I generate a GitHub Actions CI workflow? [Y/n]"

If yes, select the appropriate template based on stack:
- **Node.js/TypeScript**: lint + typecheck + test + build + `npm audit`
- **Python**: lint + typecheck + test + `pip-audit`
- **Go**: vet + staticcheck + test + `govulncheck`
- **Rust**: clippy + test + `cargo audit`

All templates include `SKIP_CLAUDE_REVIEW=1` env var (pre-commit hook must not run in CI).

**→ Save session state** (`last_phase_completed: 3`) before proceeding.

---

## PHASE 4 — SCAFFOLD + FIRST COMMIT

### Create Directory Structure

Create all directories from the confirmed folder tree. Use placeholder files (`.gitkeep` for empty dirs, or proper index files for module roots).

For each module directory, create a minimal index file that:
- Exports nothing yet (but sets up the correct module pattern)
- Has a comment explaining what belongs in this module

### Run Setup

```bash
bash scripts/setup.sh
```

If setup.sh fails, diagnose and fix before proceeding.

### First Commit

Stage all generated files:
```bash
git add spec/ ARCHITECTURE.md PATTERNS.md manta.patterns.json .env.example .gitignore README.md .github/ src/ tests/
```

Show proposed commit message:
> "chore: initialize [Project Name] — spec-driven setup
>
> - Full project specification (12 sections)
> - Architecture: [pattern] with [N] modules
> - Project scaffold: [N] directories
> - Git hooks active: pre-commit review pipeline"

Ask: "Commit this? [Y/n]"

If yes, commit. Do not push — that's the developer's choice.

**→ Delete session state file** (init is complete):
```bash
rm -f .claude/init-state.json
```

### First Feature Stub (Bonus)

After the commit, ask:
> "What's your first P0 feature to implement? I can stub out the initial files — service, repository, route handler, and test file — so you start coding immediately with the right structure."

If they name a feature, create the stubs using the confirmed module structure.

---

## PHASE 5 — HANDOFF

Print the setup summary:

```
╔══════════════════════════════════════════════════════════════╗
║          Project Initialized: [PROJECT_NAME]                 ║
╚══════════════════════════════════════════════════════════════╝

SPEC               spec/SPEC.md                [N/12 sections]
ARCHITECTURE       ARCHITECTURE.md             [pattern + N modules]
PATTERNS           manta.patterns.json         [pre-commit pattern enforcement]
SCAFFOLD           [N directories created]
GIT HOOKS          pre-commit + pre-push        active

STACK:             [language] + [framework] + [database]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DEVELOPMENT WORKFLOW:
  1. Write code in the agreed module structure
  2. git commit → agents review automatically
     CRITICAL issues block the commit
     Fix and recommit
  3. git push → security sweep
  4. Run /project:review for an interactive pre-commit review

USEFUL COMMANDS:
  /project:review         Interactive review of staged changes
  /project:security-scan  Full repository security audit
  /project:generate-tests Generate missing tests
  /project:update-docs    Update README and CHANGELOG
  /project:blueprint      Visual map of your codebase
  /project:scaffold "x"   Generate feature boilerplate

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

You're set up. Start building [PROJECT_NAME].
```

---

## Error Handling

- **Git not initialized**: `git init && git add .gitkeep` — then continue
- **setup.sh fails**: Read the error, diagnose, fix it, then re-run
- **Developer goes quiet / gives one-word answers**: Ask one specific, closed question ("Is this for consumers or business users?") rather than repeating an open one
- **Developer contradicts earlier answer**: Announce the change, confirm it, update working state, note what downstream artifacts are affected
- **Developer says "I don't know" to a required field**: Record it as `[TBD — decide before implementing affected feature]` and flag it as a WARNING in the spec
