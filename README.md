# Manta

<p align="center">
  <img src="https://drive.google.com/uc?export=view&id=1Z4H0gpwkAcYIODVD_st3qp0SPI0ehMjt" alt="Mantacron" width="200" />
</p>

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                               M A N T A                                       ║
║                  19-agent · 21-command AI pipeline · free                     ║
║                                                                               ║
║         Every commit reviewed.  Every secret caught.  Free forever.           ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

**19 agents. 21 commands. 2 git hooks. Works on new projects and existing codebases.**

> Works with **[Claude Code](https://claude.ai/code)**, **[OpenAI Codex](https://github.com/openai/codex)**, **[Google Gemini CLI](https://github.com/google-gemini/gemini-cli)**, and **[GitHub Copilot](https://github.com/features/copilot)**. Git hooks auto-detect whichever CLI is installed.

---

## What It Does

Manta embeds an automated review team into your git workflow. On every `git commit`, four agents run in parallel and block anything dangerous before it lands in your repo.

| When | Agents | What Gets Caught |
|------|--------|-----------------|
| `git commit` | 3–4 agents | Secrets, injection flaws, OWASP Top 10, N+1 queries, bad migrations (trigger-routed), DRY violations, naming issues |
| `git push` | 3–4 agents | Full branch review — same checks, broader scope (db-migration trigger-routed) |
| On demand | All agents | Security scan, blueprint, scaffold, UI generation, test generation |

You don't change how you work. You just stop shipping bugs and secrets.

---

## Quickstart

### New project

```bash
# 1. Install
gh repo clone mantacron/manta /tmp/manta && bash /tmp/manta/scripts/install.sh && rm -rf /tmp/manta

# 2. Open your AI assistant:

# Claude Code (full /project: command suite):
claude
/project:poc          # fastest: 3 questions → spec + skeleton in under 5 minutes
# — or —
/project:init         # full wizard: spec + architecture + scaffold + first commit

# Codex or Gemini (natural language — describe what you want):
# codex "set up a new project: create a spec, directory structure, and first commit"
# gemini "set up a new project: create a spec, directory structure, and first commit"
```

Then use the build loop:
```bash
/project:scaffold "feature"   # boilerplate skeleton with TODOs (Claude Code)
# — or —
/project:write "feature"      # complete implementation — auth, validation, pagination baked in (Claude Code)

git commit                    # review hook fires automatically (all tools)
```

### Existing project

```bash
# 1. Install into your existing repo
gh repo clone mantacron/manta /tmp/manta && bash /tmp/manta/scripts/install.sh && rm -rf /tmp/manta

# 2. Run an initial audit — pick your tool:

# Claude Code:
claude
/project:audit               # health scan → report with score + quick wins
/project:capture-patterns    # detect your team's conventions → PATTERNS.md

# Codex:
codex "run a full audit of this codebase and report security issues, code quality problems, and quick wins"
codex "scan this codebase and detect our coding conventions — naming, folder structure, error handling"

# Gemini:
gemini "run a full audit of this codebase and report security issues, code quality problems, and quick wins"
gemini "scan this codebase and detect our coding conventions — naming, folder structure, error handling"
```

Done. Every `git commit` now triggers the review pipeline automatically — regardless of which AI tool you use. If a commit is blocked, run `/project:fix` in Claude Code, or ask Codex/Gemini to suggest fixes for the issues listed above.

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
| `/project:poc` | Fast POC setup — 3 questions → lightweight spec + project skeleton. No interview, no phases |
| `/project:review` | Interactive 4-agent review of staged changes |
| `/project:security-scan` | Full repository security audit (secrets + OWASP) |
| `/project:fix [--apply]` | AI fix suggestions for the last blocked commit; `--apply` walks through each with Y/n and writes to files |
| `/project:explain [target]` | Plain-language explanation of any file, function, or flow — callers, dependencies, execution path |
| `/project:debt` | Harvest `// manta-defer:` annotations into a ledger; flags deferrals with no exit condition (NO-TRIGGER) |
| `/project:scaffold "feature"` | Generate boilerplate matching your project's conventions |
| `/project:write "feature"` | Write complete production-ready implementation — rate limiting, auth, validation, pagination, transactions baked in |
| `/project:ui [path]` | Convert screenshots/wireframes into responsive, accessible components |
| `/project:blueprint` | Generate a visual map of your codebase (stack, API inventory, ER diagram) |
| `/project:generate-tests` | Interactively generate missing tests |
| `/project:update-docs` | Keep README and CHANGELOG in sync with recent changes |
| `/project:capture-patterns` | Auto-detect your team's coding conventions, write to `PATTERNS.md` |
| `/project:wiki [--url=URL]` | Generate product wiki → `docs/wiki/` — route discovery, screenshots, feature analysis, spec comparison when SPEC.md exists |
| `/project:rpi:research "slug"` | RPI Phase 1 — 6-agent GO/NO-GO gate → `rpi/{slug}/research/RESEARCH.md` |
| `/project:rpi:plan "slug"` | RPI Phase 2 — UX, engineering plan, PLAN.md → `rpi/{slug}/plan/` |
| `/project:rpi:implement "slug"` | RPI Phase 3 — phased implementation with gates → `rpi/{slug}/implement/IMPLEMENT.md` |

---

## RPI Workflow (Research → Plan → Implement)

Instead of writing code immediately, run the 4-step structured workflow for any non-trivial feature:

```
Step 1 — Write rpi/{slug}/REQUEST.md     ← describe the feature in plain language
Step 2 — /project:rpi:research {slug}   ← 6 agents evaluate feasibility → GO/NO-GO
Step 3 — /project:rpi:plan {slug}       ← UX + engineering plan + risk assessment
Step 4 — /project:rpi:implement {slug}  ← phased code with gates, never all at once
```

**Why:** Spending 5 minutes on research + planning catches scope problems, tech debt, and constitutional violations before a line of code is written. The GO/NO-GO gate (technical-cto-advisor) won't let you proceed if the cost outweighs the value.

---

## All 19 Agents

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
| `ui-component-writer` | Converts design files into responsive, accessible, DRY-compliant components |
| `wiki-agent` | Generates product wiki in `docs/wiki/` — route/screen discovery, screenshots, feature analysis, spec comparison when SPEC.md exists |
| `requirement-parser` | Parses `rpi/{slug}/REQUEST.md` into structured requirements, complexity estimate, and clarifying questions |
| `product-manager` | Evaluates feature viability — user value, strategic fit, constitution compliance; recommends Build / Defer / Decline |
| `ux-planner` | Designs user journeys, component inventory, interaction states, and accessibility notes for RPI features |
| `senior-software-engineer` | Technical feasibility assessment + phased implementation (dual role: research + code execution) |
| `technical-cto-advisor` | Final GO / CONDITIONAL GO / DEFER / NO-GO decision with confidence score and rationale |
| `constitutional-validator` | Validates features against CONSTITUTION.md — mission alignment, human oversight, data privacy, reversibility |
| `documentation-analyst-writer` | Synthesizes agent outputs into RESEARCH.md, pm.md, ux.md, eng.md, PLAN.md, and IMPLEMENT.md |

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

## AI Tool Compatibility

| | Claude Code | Codex CLI | Gemini CLI | GitHub Copilot |
|---|:---:|:---:|:---:|:---:|
| Git hook review pipeline (pre-commit / pre-push) | ✓ | ✓ | ✓ | ✓ |
| Multi-agent parallel execution | ✓ | — | — | — |
| `/project:` slash commands | ✓ | — | — | — |
| Run any command manually | ✓ | ✓ | ✓ | — |
| Coding guidance (conventions, patterns, security) | ✓ | ✓ | ✓ | ✓ |

**Codex and Gemini** can run any command by passing the prompt file directly — same logic, executes sequentially instead of as parallel sub-agents:
```bash
codex "$(cat .claude/commands/audit.md)"
gemini "$(cat .claude/commands/security-scan.md)"
```

**GitHub Copilot** participates via `.github/copilot-instructions.md` — project conventions, security rules, and patterns are enforced when writing code in the IDE. It does not run the audit pipeline.

---

## What It Does Not Do

Manta won't make product decisions, design your system, or replace engineering judgment. What it eliminates is the *mechanical, repeatable* review work — catching the kinds of issues a thorough code reviewer would catch, before the PR is even opened.

Need compliance enforcement, health scoring, penetration testing, or spec-driven governance? Those are in **[Manta Enterprise](https://mantacron.github.io/manta-enterprise/)**.

---

## Manta Enterprise

Manta Enterprise is built for engineering teams in regulated industries. On top of everything in Community, it adds:

| | Community | Enterprise |
|---|:---:|:---:|
| Pre-commit review (4 agents, db-migration trigger-routed) | ✓ | ✓ |
| Pre-push review | 3–4 agents (trigger-routed) | up to 9 agents (trigger-routed) |
| Code generation (scaffold, write, ui) | ✓ | ✓ |
| Security scan | OWASP + secrets | + CVE audit, license check, dead deps |
| Blueprint | ✓ | + drift analysis |
| Test generation | ✓ | + test-architect enforcement |
| **Spec governance** (`spec-guardian`) | — | ✓ |
| **Compliance enforcement** (GDPR / HIPAA / PCI-DSS / SOC 2) | — | ✓ |
| **Zero-trust enforcement** (IAM, mTLS, RBAC, token TTLs) | — | ✓ |
| **Observability checks** | — | ✓ |
| **Health scoring + trend reports** | — | ✓ |
| **Penetration testing** | — | ✓ |
| **Log analysis** | — | ✓ |
| Agents | 19 | 30 |
| Commands | 21 | 32 |

The enterprise tier is what compliance officers, CISOs, and engineering VPs need: continuous automated enforcement of GDPR/HIPAA/SOC 2, codebase health scores for leadership reporting, zero-trust architecture audits, and formal pentest reports — replacing work that would otherwise require 10–12 specialists.

**[Learn more →](https://mantacron.github.io/manta-enterprise/)**

---

## Requirements

- One AI CLI — whichever you prefer:
  - [Claude Code](https://claude.ai/code): `npm install -g @anthropic-ai/claude-code` — full `/project:` command suite
  - [OpenAI Codex](https://github.com/openai/codex): `npm install -g @openai/codex` — review pipeline + natural-language code gen
  - [Google Gemini CLI](https://github.com/google-gemini/gemini-cli): `npm install -g @google/gemini-cli` — review pipeline + natural-language code gen
  - [GitHub Copilot](https://github.com/features/copilot): VS Code / JetBrains extension — code writing with Manta's conventions baked in
- Git repository
- Any language (TypeScript, Python, Go, Rust, Ruby, Java, Kotlin, C/C#/C++, PHP, Swift)

---

## Installation Options

**From a local clone:**
```bash
gh repo clone mantacron/manta /tmp/manta && bash /tmp/manta/scripts/install.sh && rm -rf /tmp/manta
```

**Force overwrite existing files:**
```bash
bash scripts/install.sh --force
```

---

## Updating to the Latest Version

When fixes, new agents, or new commands are pushed to Manta, run the installer again from inside your project root:

```bash
# Pull and apply the latest Manta agents, commands, and hooks:
gh repo clone mantacron/manta /tmp/manta && bash /tmp/manta/scripts/install.sh --force && rm -rf /tmp/manta
```

The `--force` flag overwrites all Manta boilerplate files (`agents/`, `commands/`, `.githooks/`, `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`) with the latest versions. Your project files (`spec/SPEC.md`, `ARCHITECTURE.md`, `RISKS.md`, `CONSTITUTION.md`, `PATTERNS.md`, `.env`, `.gitignore`, `README.md`, `CHANGELOG.md`) are **never touched** — only Manta's own files are updated.

**What gets updated:**
- All agent `.md` files in `.claude/agents/`
- All command `.md` files in `.claude/commands/`
- Git hooks in `.githooks/`
- `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `.github/copilot-instructions.md`
- Helper scripts in `scripts/`

**What is never overwritten:**
- Your spec, architecture, risks, and constitution files
- Your `.env` and `.gitignore`
- Your `README.md`, `CHANGELOG.md`, and `manta.patterns.json`
- Any file in `src/`, `app/`, or your project source directories

After updating, commit the changed files:
```bash
git add .claude/ .githooks/ scripts/ CLAUDE.md AGENTS.md GEMINI.md
git commit -m "chore: update Manta to latest"
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
