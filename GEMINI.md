# Manta — AI Review Pipeline

Automated code review on every commit. Security scanning, code quality, performance analysis — all in your git workflow.

> **Gemini CLI users**: The `/project:` slash commands in this repo are Claude Code native. Use `gemini` naturally — describe what you want to do (e.g. "review my staged changes for security issues") and the system will guide you.

---

## What Manta Does

On every `git commit`: 4 agents review staged changes. CRITICAL findings block the commit.
On every `git push`: 3–4 agents run a branch review (db-migration trigger-routed). CRITICAL and WARNING both block.

---

## Pre-Commit / Pre-Push Output Format

When asked to act as the pre-commit reviewer, output EXACTLY this format (the git hook parses it):

```
=== MANTA PRE-COMMIT REVIEW ===

STAGED FILES:
[list of staged files]

AGENT RESULTS:
security-sentinel: [PASS|WARN|BLOCK]
code-quality: [PASS|WARN|BLOCK]
perf-analyzer: [PASS|WARN|BLOCK]
db-migration-guardian: [PASS|WARN|BLOCK|SKIP]

CRITICAL ISSUES:
[numbered list or "None"]

WARNINGS:
[numbered list or "None"]

=== END REVIEW ===

COMMIT_VERDICT: PASS
```

Or if blocking:
```
COMMIT_VERDICT: BLOCK
BLOCK_REASON: N critical issues found — see above
```

Or if warnings only:
```
COMMIT_VERDICT: WARN
BLOCK_REASON: N warnings found — see above
```

For pre-push reviews, use `PUSH_VERDICT: PASS` or `PUSH_VERDICT: BLOCK` (with `BLOCK_REASON:`).

---

## Severity Levels

| Level | Meaning | Blocks Commit? | Blocks Push? |
|-------|---------|:--------------:|:------------:|
| `CRITICAL` | Must fix — security risk, broken logic | YES | YES |
| `WARNING` | Fix before pushing — code smell, quality issues | NO (shown) | YES |
| `INFO` | Optional improvement | NO | NO |

---

## Principles

1. **Security by default** — treat all external input as untrusted
2. **Clean over clever** — readable code beats micro-optimized code unless benchmarked
3. **Test the behavior, not the implementation** — tests should survive refactors
4. **No dead code** — remove it, don't comment it out
5. **Explicit over implicit** — name things clearly, avoid magic

---

## What You Can Help With

- **Review staged changes**: run security, quality, performance, and migration checks
- **Audit the codebase**: full health check with scores and quick wins
- **Write features**: production-ready implementations with auth, validation, rate limiting, pagination, transactions
- **Scaffold features**: boilerplate matching project conventions
- **Generate tests**: find untested code and generate coverage
- **Explain code**: plain-language walkthrough of files, functions, or flows
- **Fix issues**: read flagged files and suggest concrete fixes
- **Update docs**: README.md and CHANGELOG.md maintenance
- **Generate blueprint**: stack detection, API inventory, ER diagrams, module maps

---

## Suppressing Findings

**File-level suppressions** — add a `.mantaignore` file to the project root:

```
# Suppress MD5 findings in hash utility (non-security use)
src/utils/hash.ts  MD5

# Suppress DRY warnings in generated code
src/generated/**  DRY

# Suppress all INFO findings globally
**  INFO
```

Format: `[file-glob]  [keyword-or-severity]  # optional reason`

**Inline suppressions** — suppress a specific line:

```typescript
const hash = md5(data); // manta-ignore: non-security hash for cache key
```

**Deferral annotations** — mark intentional shortcuts:

```typescript
// manta-defer: in-memory cache, ceiling: >100 concurrent users, trigger: load test shows p95 > 200ms
const cache = new Map();
```

---

## Pattern Enforcement

| File | Purpose |
|------|---------|
| `manta.patterns.json` | Machine-readable conventions — read this first |
| `PATTERNS.md` | Human-readable docs — team reference |

When reviewing code, read `manta.patterns.json` to enforce project-specific conventions.

---

## Scan Exclusions

Always exclude these directories from any file scan or grep:

```bash
node_modules  vendor  dist  build  out  .next  .nuxt  .svelte-kit
__pycache__  .venv  venv  .eggs  target  .gradle  Pods  .build
bower_components  .yarn  coverage  .nyc_output  .git  reports
```

For grep:
```bash
grep -r --exclude-dir={node_modules,vendor,dist,build,out,.next,.nuxt,.svelte-kit,__pycache__,.venv,venv,target,.gradle,Pods,.build,bower_components,.yarn,coverage,.nyc_output,.git,.idea,.vscode,reports} ...
```

---

## Agent Reference

| Agent | Scope |
|-------|-------|
| `security-sentinel` | OWASP Top 10, CVEs, secrets, injection |
| `code-quality` | DRY, complexity, naming, edge cases |
| `perf-analyzer` | N+1, memory leaks, hot path issues |
| `db-migration-guardian` | Migration safety: blocking ops, missing rollbacks |
| `remediation-agent` | Fix suggestions for flagged files |
| `scaffolding-agent` | Feature boilerplate matching project conventions |
| `code-writer` | Complete production-ready implementations |
| `doc-keeper` | README and CHANGELOG maintenance |
| `pr-summarizer` | PR summary generation |
| `blueprint-agent` | Stack detection, API map, ER diagram, module map |
| `ui-component-writer` | Convert designs into accessible components |
| `wiki-agent` | Generate product wiki in `docs/wiki/` |

---

## Subdirectory Mode

When Manta is installed as a subfolder inside a project (e.g. `my-project/community/`), all project files are one level up:

- Use `../src/`, `../package.json`, `../reports/`, etc.
- Git operations target the parent project automatically
- Never create project artifacts inside the `community/` folder itself

Detect subdirectory mode:
```bash
git rev-parse --show-toplevel  # if one level up from pwd, you're in subdirectory mode
```
