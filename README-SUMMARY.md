# Manta — Quick Reference

11-agent AI review pipeline embedded in your git workflow. Catches security issues, bugs, and bad migrations before they land in your repo. Free forever.

---

## Install

```bash
git clone https://github.com/mantacron/manta /tmp/manta
bash /tmp/manta/scripts/install.sh
rm -rf /tmp/manta
claude
/project:init
```

---

## How It Works

```
git commit  →  4 agents  →  CRITICAL blocks commit
git push    →  4 agents  →  CRITICAL + WARNING blocks push
```

**CRITICAL** = security risk, broken migration, dangerous flaw — blocks immediately.  
**WARNING** = code smell, quality issue — shown at commit, blocks at push.  
**INFO** = optional suggestion — never blocks.

Bypass (emergency only):
```bash
SKIP_MANTA_REVIEW=1 git commit
SKIP_CLAUDE_PUSH_REVIEW=1 git push
```

---

## The 4 Core Agents (Every Commit)

| Agent | What it catches |
|-------|-----------------|
| `security-sentinel` | Secrets, API keys, SQL injection, XSS, auth bypass, OWASP Top 10 |
| `code-quality` | DRY violations, complexity, dead code, naming, missing error handling |
| `perf-analyzer` | N+1 queries, memory leaks, blocking async, O(n²) algorithms |
| `db-migration-guardian` | Table locks, missing rollbacks, unsafe NOT NULL — runs only when migrations staged |

---

## All 11 Agents

| Agent | Purpose |
|-------|---------|
| `security-sentinel` | OWASP Top 10, secrets, injection, auth issues |
| `code-quality` | DRY, complexity, naming, edge cases, dead code |
| `perf-analyzer` | N+1, memory leaks, blocking async, bundle bloat |
| `db-migration-guardian` | Migration safety — locking, rollback, irreversible ops |
| `remediation-agent` | Fix suggestions for blocked commits |
| `scaffolding-agent` | Feature boilerplate matching project conventions |
| `code-writer` | Complete production implementation — auth, rate limiting, validation, pagination, transactions |
| `doc-keeper` | Keeps README and CHANGELOG in sync |
| `pr-summarizer` | Auto-generates PR summaries |
| `blueprint-agent` | Stack map, API inventory, ER diagram, module tree |
| `ui-ux-agent` | Design files → accessible, DRY components |

---

## Commands

| Command | What it does |
|---------|-------------|
| `/project:init` | New project wizard or quick setup for existing code |
| `/project:review` | Manual 4-agent review of staged changes |
| `/project:fix` | AI fix suggestions for the last blocked commit |
| `/project:security-scan` | Full repo security audit |
| `/project:scaffold "feature"` | Boilerplate skeleton — you fill in the logic |
| `/project:write "feature"` | Complete production implementation — auth, rate limiting, pagination baked in |
| `/project:ui [path]` | Convert screenshots/wireframes → responsive components |
| `/project:blueprint` | Generate codebase map (stack, API inventory, ER diagram) |
| `/project:generate-tests` | Interactively generate missing tests |
| `/project:update-docs` | Update README and CHANGELOG |
| `/project:capture-patterns` | Auto-detect conventions → write to PATTERNS.md |

---

## Suppressing False Positives

```
# .mantaignore — format: [file-glob]  [keyword-or-severity]
src/utils/hash.ts    MD5       # Non-security use
src/generated/**     DRY       # Generated code
**                   INFO      # Suppress all INFO globally
```

---

## Want More?

**Manta Enterprise (Cathy)** adds: compliance enforcement (GDPR/HIPAA/PCI-DSS/SOC 2), health scoring, penetration testing, spec governance, observability checks, zero-trust enforcement — 21 agents, 25 commands.

Full documentation: [README.md](README.md)
