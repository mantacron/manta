Non-interactive pre-commit review for use by the git pre-commit hook. Reviews staged changes and outputs a machine-readable verdict.

## Instructions

Run a fast, focused review of staged changes. Output must be structured for machine parsing.

Runs 4 agents only — the high-signal blockers. Spec alignment, test coverage, compliance, and
observability checks run at push time instead (see pre-push-review.md).

### Step 1: Load suppressions

```bash
cat .mantaignore 2>/dev/null
```

If `.mantaignore` exists, parse its suppression rules (skip comment lines starting with `#` and blank lines). Store them — before adding any finding to the output, check if the finding's file path matches the glob and the issue description/title contains the keyword. If it matches, silently skip that finding.

### Step 2: Get staged changes

```bash
git diff --cached --name-only
git diff --cached
```

If there are no staged changes, output `COMMIT_VERDICT: PASS` and exit.

### Step 3: Run agents in parallel

Use the Agent tool to run these agents simultaneously:
- **security-sentinel**: full security check including dependency audit
- **code-quality**: check for CRITICAL quality issues only (skip INFO)
- **perf-analyzer**: check for CRITICAL performance issues only
- **db-migration-guardian**: validate migration safety (auto-skips if no migration files staged)

### Step 4: Output structured result

Output EXACTLY in this format (the git hook parses this):

```
=== CLAUDE PRE-COMMIT REVIEW ===

STAGED FILES:
[list of staged files]

AGENT RESULTS:
security-sentinel: [PASS|WARN|BLOCK]
code-quality: [PASS|WARN|BLOCK]
perf-analyzer: [PASS|WARN|BLOCK]
db-migration-guardian: [PASS|WARN|BLOCK|SKIP]

CRITICAL ISSUES:
[If any CRITICAL findings from any agent, list them here numbered]
[Format: N. [AGENT] [file:line] — [issue description]]
[If none: "None"]

WARNINGS:
[If any WARNING findings, list numbered]
[If none: "None"]

=== END REVIEW ===

COMMIT_VERDICT: PASS
```

OR if there are critical issues:

```
COMMIT_VERDICT: BLOCK
BLOCK_REASON: [N critical issues found — see above]
```

OR if there are warnings but no critical issues:

```
COMMIT_VERDICT: WARN
BLOCK_REASON: [N warnings found — see above]
```

### Rules

- Be fast — this runs on every commit
- CRITICAL findings block the commit (`COMMIT_VERDICT: BLOCK`)
- WARNING findings allow the commit but are shown prominently (`COMMIT_VERDICT: WARN`) — they will block at push time
- INFO findings never affect the verdict
- The last two lines must always be `COMMIT_VERDICT: PASS`, `COMMIT_VERDICT: BLOCK`, or `COMMIT_VERDICT: WARN` followed by `BLOCK_REASON`
- Do not ask questions — this is non-interactive
- Do not offer test generation — that's for the interactive `/project:review` command
- Before reporting any finding, check `.mantaignore` if it exists — suppress any finding matching a rule in that file
