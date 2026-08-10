# Manta

Automated code review on every commit. Security scanning, code quality, performance analysis — all in your git workflow.

---

## Setup (One-Time)

```bash
bash scripts/install.sh
```

Then open Claude Code:
```
/init
```

---

## Workflow

```
/init         ← start here for new projects
     ↓
/rpi-research "feature"  ← 6-agent GO/NO-GO gate → RESEARCH.md
/rpi-plan "feature"      ← UX + engineering plan → PLAN.md
/rpi-implement "feature" ← phased code with gates
     ↓  (or skip RPI for simple changes:)
/scaffold "feature"   ← generate code skeleton (boilerplate, TODOs to fill)
/write "feature"      ← generate complete implementation (no TODOs, enterprise patterns)
/ui [design]          ← convert design files into components
     ↓
git commit
     ↓
Pre-commit hook fires → 4 agents review staged changes
(security-sentinel, code-quality, perf-analyzer, db-migration-guardian)
     ↓
CRITICAL? → Commit BLOCKED
WARNING? → Commit allowed, shown prominently
     → Run /fix for AI-generated fix suggestions
     ↓
git push → 3–4 agent branch review (db-migration-guardian trigger-routed: skips when no migration files in diff)
     ↓
PR opened → PR summary generated automatically
```

---

## Agent Reference

Agent definitions live in `.claude/agents/<name>.md` — that file is the agent's
full prompt and the authority on its scope. `ls .claude/agents/` lists the set
available in this install.

---

## RPI Workflow

For non-trivial features, use the structured Research → Plan → Implement workflow before writing any code:

```
Step 1: write rpi/{slug}/REQUEST.md          ← plain-language feature description
Step 2: /rpi-research {slug}         ← 6-agent GO/NO-GO gate → rpi/{slug}/research/RESEARCH.md
Step 3: /rpi-plan {slug}             ← pm.md, ux.md, eng.md, PLAN.md → rpi/{slug}/plan/
Step 4: /rpi-implement {slug}        ← phased implementation + gates → rpi/{slug}/implement/IMPLEMENT.md
```

Feature folder structure:
```
rpi/{slug}/
  REQUEST.md          ← your feature description
  research/
    RESEARCH.md       ← synthesized GO/NO-GO report
  plan/
    pm.md             ← product requirements
    ux.md             ← UX flows and component specs
    eng.md            ← architecture and data model
    PLAN.md           ← phased implementation plan with gates
  implement/
    IMPLEMENT.md      ← phase log and final status
```

---

## Agent-Scoped Memory

Agents that benefit from persistent state across sessions write to `.claude/agent-memory/{agent}/MEMORY.md`. Currently:

- `wiki-agent/MEMORY.md` — tracks detected stack, routes, screenshot status, spec gaps, and answered clarifying questions

Agents read this at startup and update it after each run. Add new agents by creating `.claude/agent-memory/{agent-name}/MEMORY.md` with the fields the agent needs to persist.

---

## Commands

Command definitions live in `.claude/commands/<name>.md`; `ls .claude/commands/`
lists them all.

Everyday entry points: `/init` (setup) · `/audit` (health report) · `/review`
(staged changes) · `/fix` (fix suggestions) · `/write` and `/scaffold` (codegen)
· `/rpi-research`, `/rpi-plan`, `/rpi-implement` (feature workflow).

---

## Severity Levels

| Level | Meaning | Blocks Commit? | Blocks Push? |
|-------|---------|:--------------:|:------------:|
| `CRITICAL` | Must fix — security risk, broken logic | YES | YES |
| `WARNING` | Fix before pushing — code smell, quality issues | NO (shown) | YES |
| `INFO` | Optional improvement | NO | NO |

---

## Scan Exclusions

**Always exclude these directories** from any file scan, grep, or find operation — dependency installs, build artifacts, and generated output, never source code:

`node_modules` `vendor` `dist` `build` `out` `.next` `.nuxt` `.svelte-kit` `__pycache__` `.venv` `venv` `target` `.gradle` `Pods` `.build` `bower_components` `.yarn` `coverage` `.nyc_output` `.git` `reports`

```bash
# For grep — one flag covers the whole list:
grep -r --exclude-dir={node_modules,vendor,dist,build,out,.next,.nuxt,.svelte-kit,__pycache__,.venv,venv,target,.gradle,Pods,.build,bower_components,.yarn,coverage,.nyc_output,.git,reports} ...

# For find — add ! -path "*/<dir>/*" for each directory in the list above
```

---

## Suppressing Findings

Add a `.mantaignore` file to the project root:

```
# Suppress MD5 findings in hash utility (non-security use)
src/utils/hash.ts  MD5

# Suppress DRY warnings in generated code
src/generated/**  DRY

# Suppress all INFO findings globally
**  INFO
```

Format: `[file-glob]  [keyword-or-severity]  # optional reason`

---

## Pattern Enforcement

Manta enforces project-specific coding conventions at pre-commit via two config files:

| File | Purpose |
|------|---------|
| `manta.patterns.json` | Machine-readable config — agents read this first |
| `PATTERNS.md` | Human-readable docs — team reference |

```
/capture-patterns   ← auto-scans codebase and writes both files
```

---

## Subdirectory Mode

When Manta Community is installed as a subfolder inside a project (e.g. `my-project/community/`), all agents and commands must target the **parent directory** for project files — not the `community/` folder itself.

**How to detect subdirectory mode:**
```bash
# If this returns a path one level up from pwd, you're in subdirectory mode
git rev-parse --show-toplevel
```

**Rules when in subdirectory mode:**
- All file creation (spec, architecture, scaffold, reports, etc.) goes to `../` — the parent project root
- All file reads (source code, package.json, existing specs) use `../` as the base
- Git operations (staged files, diffs, log) target the parent automatically via the git environment
- **Never create project artifacts inside the `community/` folder itself**

**Path translation:**
| Instead of | Use |
|---|---|
| `spec/SPEC.md` | `../spec/SPEC.md` |
| `src/` | `../src/` |
| `package.json` | `../package.json` |
| `reports/` | `../reports/` |
| `docs/BLUEPRINT.md` | `../docs/BLUEPRINT.md` |
| `ARCHITECTURE.md` | `../ARCHITECTURE.md` |
| `.env.example` | `../.env.example` |
| `README.md` | `../README.md` |
| `PATTERNS.md` | `../PATTERNS.md` |
| `manta.patterns.json` | `../manta.patterns.json` |
| `.mantaignore` | `../.mantaignore` |

This applies to every agent and every command — `/init`, `/scaffold`, `/write`, `/audit`, `/blueprint`, and all others.

---

## Principles

1. **Security by default** — treat all external input as untrusted
2. **Clean over clever** — readable code beats micro-optimized code unless benchmarked
3. **Test the behavior, not the implementation** — tests should survive refactors
4. **No dead code** — remove it, don't comment it out
5. **Explicit over implicit** — name things clearly, avoid magic
