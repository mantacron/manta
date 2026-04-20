# Manta Community

<p align="center">
  <img src="https://drive.google.com/uc?export=view&id=1Z4H0gpwkAcYIODVD_st3qp0SPI0ehMjt" alt="Mantacron" width="200" />
</p>

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                               M A N T A                                        ║
║                    11-agent AI pipeline · community edition                   ║
║                                                                               ║
║         Every commit reviewed.  Every secret caught.  Free forever.          ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

**11 agents. 14 commands. 2 git hooks. Works on new projects and existing codebases.**

---

## What It Does

Manta embeds an automated review team into your git workflow. On every `git commit`, four agents run in parallel and block anything dangerous before it lands in your repo.

| When | Agents | What Gets Caught |
|------|--------|-----------------|
| `git commit` | 4 agents | Secrets, injection flaws, OWASP Top 10, N+1 queries, bad migrations, DRY violations, naming issues |
| `git push` | 4 agents | Full branch review — same checks, broader scope |
| On demand | All agents | Security scan, blueprint, scaffold, UI generation, test generation |

You don't change how you work. You just stop shipping bugs and secrets.

---

## Quickstart

```bash
# Install into your project
bash /path/to/manta-community/scripts/install.sh

# Open Claude Code and run the setup wizard
claude
/project:init
```

That's it. The next `git commit` will trigger the review pipeline.

---

## The 4 Core Agents (Run on Every Commit)

| Agent | What It Catches |
|-------|----------------|
| **security-sentinel** | Hardcoded secrets, API keys, SQL injection, XSS, auth bypass, OWASP Top 10 |
| **code-quality** | DRY violations, high complexity, dead code, poor naming, missing error handling |
| **perf-analyzer** | N+1 queries, memory leaks, blocking async operations, O(n²) algorithms |
| **db-migration-guardian** | Table locks, missing rollbacks, unsafe `NOT NULL`, irreversible changes |

A `CRITICAL` finding blocks the commit. A `WARNING` shows prominently and blocks the push.
Run `/project:fix` to get AI-generated fix suggestions for whatever was caught.

---

## Developer Commands

| Command | What It Does |
|---------|-------------|
| `/project:init` | New project wizard (spec + architecture + scaffold) or quick setup for existing code |
| `/project:review` | Interactive 4-agent review of staged changes |
| `/project:security-scan` | Full repository security audit (secrets + OWASP) |
| `/project:fix` | AI fix suggestions for the last blocked commit |
| `/project:scaffold "feature"` | Generate boilerplate matching your project's conventions |
| `/project:write "feature"` | Write complete production-ready implementation — rate limiting, auth, validation, pagination, transactions baked in |
| `/project:ui [path]` | Convert screenshots/wireframes into responsive, accessible components |
| `/project:blueprint` | Generate a visual map of your codebase (stack, API inventory, ER diagram) |
| `/project:generate-tests` | Interactively generate missing tests |
| `/project:update-docs` | Keep README and CHANGELOG in sync with recent changes |
| `/project:capture-patterns` | Auto-detect your team's coding conventions, write to `PATTERNS.md` |

---

## All 11 Agents

| Agent | Purpose |
|-------|---------|
| `security-sentinel` | OWASP Top 10, hardcoded secrets, injection flaws, auth issues |
| `code-quality` | DRY, cyclomatic complexity, naming, edge cases, error handling, dead code |
| `perf-analyzer` | N+1 queries, memory leaks, blocking operations, bundle bloat |
| `db-migration-guardian` | Migration safety: locking, rollback, unsafe constraints, irreversible ops |
| `remediation-agent` | Concrete fix suggestions for blocked commits |
| `scaffolding-agent` | Feature boilerplate matching your existing project conventions |
| `code-writer` | Complete production-ready implementations — rate limiting, auth, validation, pagination, transactions, audit trail all written (not just scaffolded) |
| `doc-keeper` | Keeps README and CHANGELOG in sync with code changes |
| `pr-summarizer` | Auto-generates PR summaries for reviewers |
| `blueprint-agent` | Stack detection, API inventory, ER diagram, module map, component tree |
| `ui-ux-agent` | Converts design files into responsive, accessible, DRY-compliant components |

---

## How Much Time Does It Save?

For a solo developer or small team shipping ~10 commits/week, Manta eliminates:

| Activity | Without Manta | With Manta | Saving |
|----------|--------------|-----------|--------|
| Catching security issues before PR | 30–60 min/PR | Instant (pre-commit) | **Most of it** |
| Writing boilerplate for new features | 30–60 min | ~2 min (`/project:scaffold`) | **Most of it** |
| Writing a full feature implementation | 2–4 hrs | ~10 min (`/project:write`) | **Most of it** |
| Converting designs to components | 1–3 hrs | ~10 min (`/project:ui`) | **Most of it** |
| Keeping docs in sync | 20–30 min | ~2 min (`/project:update-docs`) | **Most of it** |
| Understanding a new codebase | 2–4 hrs | ~10 min (`/project:blueprint`) | **Most of it** |

---

## `/project:scaffold` vs `/project:write`

Two commands generate code. Use the right one for the job:

| | `/project:scaffold` | `/project:write` |
|---|---|---|
| **Output** | Skeleton with `TODO` markers | Complete, production-ready implementation |
| **Business logic** | You fill it in | Written by the agent |
| **Rate limiting** | Not added | Per-route, per-user, configurable |
| **Auth wiring** | Mirrors existing pattern | Detects and wires existing auth middleware |
| **Input validation** | Not added | DTOs + schema validation at the boundary |
| **Pagination** | Not added | Always included on list endpoints |
| **Tests** | Minimal structure | Meaningful unit + integration tests |
| **Best for** | When you want to control the implementation | When you want production-ready code fast |

**When in doubt:** use `/project:write`. Run `/project:review` after either command.

---

## What It Does Not Do

Manta won't make product decisions, design your system, or replace engineering judgment. What it eliminates is the *mechanical, repeatable* review work — catching the kinds of issues a thorough code reviewer would catch, before the PR is even opened.

Need compliance enforcement, health scoring, penetration testing, or spec-driven governance? Those are in **[Manta Enterprise](https://mantacron.github.io/manta-enterprise/)**.

---

## Manta Enterprise

Manta Enterprise is the managed version built for teams in regulated industries. It adds:

- **Compliance enforcement** — GDPR, HIPAA, PCI-DSS, SOC 2 checked on every commit
- **Health scoring & trend tracking** — codebase health reports over time, ready for leadership reporting
- **Penetration testing** — automated pentest runs on every push, not just quarterly
- **Spec & architecture governance** — architectural drift and API contract deviations caught before the PR
- **Observability checks** — every endpoint has logging, timeouts, and health checks enforced
- **21 agents** vs 11 in community, and 25 commands vs 14

**[Learn more →](https://mantacron.github.io/manta-enterprise/)**

---

## Requirements

- [Claude Code](https://claude.ai/code) CLI installed (`npm install -g @anthropic-ai/claude-code`)
- Git repository
- Any language (TypeScript, Python, Go, Rust, Ruby, Java, Kotlin, C/C#/C++, PHP, Swift)

---

## Installation Options

**From a local clone:**
```bash
git clone https://github.com/your-org/manta-community /tmp/manta
bash /tmp/manta/scripts/install.sh
rm -rf /tmp/manta
```

**Force overwrite existing files:**
```bash
bash scripts/install.sh --force
```

---

## Suppressing False Positives

Add a `.mantaignore` file to your project root:

```
# MD5 is fine here — not used for security
src/utils/hash.ts  MD5

# Generated code — DRY violations expected
src/generated/**  DRY

# Suppress all INFO globally
**  INFO
```

---

## Acceptable Use

Manta is built to help developers ship safer, higher-quality software. By using it, you agree not to:

- Run security or penetration testing agents against systems you do not own or have explicit written permission to test
- Redistribute Manta under a different name or brand without clearly crediting Mantacron
- Use Manta to facilitate attacks, data exfiltration, or unauthorized access to any system

## License

Apache 2.0 — free to use, modify, and distribute with attribution. See [LICENSE](./LICENSE).
