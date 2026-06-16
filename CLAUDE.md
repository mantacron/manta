# Manta

Automated code review on every commit. Security scanning, code quality, performance analysis — all in your git workflow.

---

## Setup (One-Time)

```bash
bash scripts/install.sh
```

Then open Claude Code:
```
/project:init
```

---

## Workflow

```
/project:init         ← start here for new projects
     ↓
/project:scaffold "feature"   ← generate code skeleton (boilerplate, TODOs to fill)
/project:write "feature"      ← generate complete implementation (no TODOs, enterprise patterns)
/project:ui [design]          ← convert design files into components
     ↓
git commit
     ↓
Pre-commit hook fires → 4 agents review staged changes
(security-sentinel, code-quality, perf-analyzer, db-migration-guardian)
     ↓
CRITICAL? → Commit BLOCKED
WARNING? → Commit allowed, shown prominently
     → Run /project:fix for AI-generated fix suggestions
     ↓
git push → 3–4 agent branch review (db-migration-guardian trigger-routed: skips when no migration files in diff)
     ↓
PR opened → PR summary generated automatically
```

---

## Agent Reference

| Agent | File | Scope |
|-------|------|-------|
| `security-sentinel` | `.claude/agents/security-sentinel.md` | OWASP Top 10, secrets, injection |
| `code-quality` | `.claude/agents/code-quality.md` | DRY, complexity, naming, edge cases |
| `perf-analyzer` | `.claude/agents/perf-analyzer.md` | N+1, memory leaks, hot path issues |
| `db-migration-guardian` | `.claude/agents/db-migration-guardian.md` | Migration safety: blocking ops, missing rollbacks |
| `remediation-agent` | `.claude/agents/remediation-agent.md` | Fix suggestions for blocked commits |
| `scaffolding-agent` | `.claude/agents/scaffolding-agent.md` | Feature boilerplate matching project conventions |
| `code-writer` | `.claude/agents/code-writer.md` | Complete production-ready implementations — rate limiting, auth, validation, pagination, transactions, audit trail all written |
| `doc-keeper` | `.claude/agents/doc-keeper.md` | README and CHANGELOG maintenance |
| `pr-summarizer` | `.claude/agents/pr-summarizer.md` | PR summary generation |
| `blueprint-agent` | `.claude/agents/blueprint-agent.md` | Stack detection, API inventory, ER diagram, module map |
| `ui-ux-agent` | `.claude/agents/ui-ux-agent.md` | Convert designs into responsive, accessible components |
| `wiki-agent` | `.claude/agents/wiki-agent.md` | Generate product wiki in `docs/wiki/` — route discovery, screenshots, feature analysis, spec comparison when SPEC.md exists |

---

## Commands

| Command | Description |
|---------|-------------|
| `/project:init` | **Start here** — new project wizard or existing codebase quick setup |
| `/project:poc` | Fast POC setup — 3 questions → lightweight spec + project skeleton; no interview, no architecture phases |
| `/project:audit [focus]` | Full codebase audit → `reports/YYYY-MM-DD-report.md` with score and quick wins |
| `/project:review` | Full review of staged changes (4 agents) |
| `/project:pre-commit-review` | Structured output for pre-commit git hook (4 agents: security, quality, perf, migrations) |
| `/project:pre-push-review` | Structured output for pre-push git hook (3–4 agents: db-migration trigger-routed) |
| `/project:generate-tests` | Interactive test generation for uncovered code |
| `/project:update-docs` | Update README.md and CHANGELOG.md |
| `/project:security-scan` | Full security audit (OWASP + secrets) |
| `/project:blueprint` | Generate `docs/BLUEPRINT.md` — stack, API map, ER diagram, module map |
| `/project:fix [--apply]` | AI fix suggestions for last blocked commit; `--apply` walks through each with Y/n and writes to files |
| `/project:explain [target]` | Plain-language explanation of any file, function, or flow — callers, dependencies, execution path |
| `/project:debt` | Harvest `// cathy-defer:` annotations into a ledger; flags deferrals with no exit condition (NO-TRIGGER) |
| `/project:scaffold "description"` | Generate feature boilerplate matching project conventions |
| `/project:write "description"` | Write complete production-ready implementation — enterprise defaults (rate limiting, auth, validation, pagination, transactions) baked in |
| `/project:ui [path or description]` | Convert designs into responsive, accessible, DRY-compliant components |
| `/project:capture-patterns` | Scan codebase and auto-generate `PATTERNS.md` + `manta.patterns.json` |
| `/project:wiki [--url=URL]` | Generate product wiki in `docs/wiki/` — route discovery, screenshots, feature analysis, spec comparison when SPEC.md exists |

---

## Severity Levels

| Level | Meaning | Blocks Commit? | Blocks Push? |
|-------|---------|:--------------:|:------------:|
| `CRITICAL` | Must fix — security risk, broken logic | YES | YES |
| `WARNING` | Fix before pushing — code smell, quality issues | NO (shown) | YES |
| `INFO` | Optional improvement | NO | NO |

---

## Scan Exclusions

**Always exclude these directories** from any file scan, grep, or find operation:

```bash
# For grep:
grep -r --exclude-dir={node_modules,vendor,dist,build,out,.next,.nuxt,.svelte-kit,__pycache__,.venv,venv,target,.gradle,Pods,.build,bower_components,.yarn,coverage,.nyc_output,.git,reports} ...

# For find:
find . -type f \
  ! -path "*/node_modules/*" ! -path "*/vendor/*" \
  ! -path "*/dist/*" ! -path "*/build/*" ! -path "*/out/*" \
  ! -path "*/.next/*" ! -path "*/.nuxt/*" ! -path "*/.svelte-kit/*" \
  ! -path "*/__pycache__/*" ! -path "*/.venv/*" ! -path "*/venv/*" \
  ! -path "*/target/*" ! -path "*/.gradle/*" ! -path "*/Pods/*" \
  ! -path "*/.build/*" ! -path "*/bower_components/*" ! -path "*/.yarn/*" \
  ! -path "*/coverage/*" ! -path "*/.nyc_output/*" ! -path "*/.git/*" \
  ! -path "*/reports/*" \
  ...
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
/project:capture-patterns   ← auto-scans codebase and writes both files
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

This applies to every agent and every command — `/project:init`, `/project:scaffold`, `/project:write`, `/project:audit`, `/project:blueprint`, and all others.

---

## Principles

1. **Security by default** — treat all external input as untrusted
2. **Clean over clever** — readable code beats micro-optimized code unless benchmarked
3. **Test the behavior, not the implementation** — tests should survive refactors
4. **No dead code** — remove it, don't comment it out
5. **Explicit over implicit** — name things clearly, avoid magic
