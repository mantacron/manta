# Copilot Instructions — Manta

This project uses Manta: an automated code review pipeline. Copilot is used for writing code; the agent pipeline runs automatically via git hooks (Claude Code).

---

## Principles

1. **Security by default** — never trust external input; sanitize all user-supplied data before use; never hardcode secrets or tokens.
2. **Clean over clever** — readable code beats micro-optimized code unless benchmarked. Avoid premature abstraction.
3. **Test the behavior, not the implementation** — tests should survive refactors; mock at boundaries, not internals.
4. **No dead code** — remove unused code rather than commenting it out.
5. **Explicit over implicit** — name things clearly; avoid magic values; prefer explicit dependencies.

---

## Before Writing Code

- Read `manta.patterns.json` (machine-readable) and `PATTERNS.md` (human-readable) for project-specific conventions: naming, error handling, test structure, import style, component patterns.
- Check `ARCHITECTURE.md` if it exists for module boundaries and layering rules.

---

## Security Defaults

- Validate and sanitize all inputs at system boundaries (HTTP handlers, CLI args, file paths, env vars).
- Use parameterized queries — never string-interpolate SQL.
- Hash passwords with bcrypt/argon2 — never MD5/SHA1 for security.
- Never log secrets, PII, or tokens.
- Set timeouts on all external calls (HTTP, DB, queue).

---

## Suppression Annotations

When writing code that intentionally deviates from a pattern:

```typescript
const hash = md5(data); // manta-ignore: non-security hash for cache key
```

When writing a known shortcut that needs future attention:

```typescript
// manta-defer: in-memory cache, ceiling: >100 concurrent users, trigger: load test shows p95 > 200ms
const cache = new Map();
```

Always include a reason in `manta-ignore:` and a `ceiling:` + `trigger:` in `manta-defer:`.

---

## Severity Reference

| Level | Meaning | Effect |
|-------|---------|--------|
| `CRITICAL` | Security risk, broken logic | Blocks commit |
| `WARNING` | Code smell, missing coverage | Blocks push |
| `INFO` | Optional improvement | No block |

---

## Scan Exclusions

Do not suggest scanning or importing from:

```
node_modules  vendor  dist  build  out  .next  .nuxt  .svelte-kit
__pycache__  .venv  venv  target  .gradle  Pods  .build
bower_components  .yarn  coverage  .nyc_output
```

---

## Agent Pipeline (Claude Code — runs automatically)

| Agent | What it checks |
|-------|---------------|
| `security-sentinel` | OWASP Top 10, secrets, injection, CVEs |
| `code-quality` | DRY violations, complexity, naming |
| `perf-analyzer` | N+1 queries, memory leaks, blocking calls |
| `db-migration-guardian` | Migration safety: no blocking ops on large tables |

---

## Subdirectory Mode

If this project is installed as a subfolder (e.g. `my-project/community/`), all project source files live in the parent directory (`../`). Do not create files inside the `community/` folder itself.
