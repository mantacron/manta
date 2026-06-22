**Begin by outputting:** `[ Manta Enterprise — Pre-Commit Review ]`

Non-interactive pre-commit review for use by the git pre-commit hook. Reviews staged changes and outputs a machine-readable verdict.

Runs 4 agents only — the high-signal blockers. Spec alignment, test coverage, compliance, and
observability checks run at push time instead (see pre-push-review.md).

## Instructions

### Step 0: Load project map (context-efficient caching)

```bash
bash scripts/build-project-map.sh 2>/dev/null || true
```

Read `.manta-cache/project-map.json` if it exists. This gives you `high_risk_files`, `migration_files`, `entry_points`, and `stack`. Share this context with agents so they don't re-scan the repo.

### Step 1: Load suppressions

```bash
cat .mantaignore 2>/dev/null
```

If `.mantaignore` exists, parse its suppression rules (skip comment lines starting with `#` and blank lines). Store them — before adding any finding to the output, check if the finding's file path matches the glob and the issue description/title contains the keyword. If it matches, silently skip that finding.

### Step 2: Shallow pre-scan (fast signal detection)

Run the shallow scanner before invoking any agents:

```bash
bash scripts/shallow-scan.sh 2>/dev/null
SHALLOW_EXIT=$?
```

Parse the output:
- `SHALLOW_SCAN: CLEAN` — no high-risk signals; run security-sentinel in SHALLOW mode (pattern checks only, skip taint analysis and dep audit)
- `SHALLOW_SCAN: SIGNALS_FOUND` — run security-sentinel in DEEP mode
- `SENTINEL_MODE: SHALLOW|DEEP` — pass this to security-sentinel directly
- `SKIP_DB_GUARDIAN: true` — skip db-migration-guardian (no migration files staged)

### Step 3: Get staged changes

```bash
git diff --cached --name-only
git diff --cached
```

If there are no staged changes, output `COMMIT_VERDICT: PASS` and exit.

### Step 4: Agent timeout budgets

| Agent | Timeout | Rationale |
|-------|---------|-----------|
| security-sentinel (SHALLOW) | 45s | Fast pattern checks only |
| security-sentinel (DEEP) | 90s | Full SAST + dep audit |
| code-quality | 45s | Diff-based, should be fast |
| perf-analyzer | 30s | Signal-based |
| db-migration-guardian | 20s | Focused file set |

TIMEOUT agents are noted but do not block the commit.

### Step 5: Run agents in parallel

Use the Agent tool to run these agents simultaneously, applying trigger routing from Step 2:

- **security-sentinel**: Always run. Pass `SENTINEL_MODE` from shallow scan.
- **code-quality**: Always run. CRITICAL issues only (skip INFO).
- **perf-analyzer**: Always run. CRITICAL issues only.
- **db-migration-guardian**: Run only if `SKIP_DB_GUARDIAN: false` (migration files staged).

Provide project map context to each agent.

### Step 6: Output structured result

Output EXACTLY in this format (the git hook parses this):

```
=== CLAUDE PRE-COMMIT REVIEW ===

STAGED FILES:
[list of staged files]

SHALLOW SCAN:
[CLEAN|SIGNALS_FOUND] — [N signals: N secrets, N injection, N crypto]
SENTINEL_MODE: [SHALLOW|DEEP]

AGENT RESULTS:
security-sentinel: [PASS|WARN|BLOCK|TIMEOUT]
code-quality: [PASS|WARN|BLOCK|TIMEOUT]
perf-analyzer: [PASS|WARN|BLOCK|TIMEOUT]
db-migration-guardian: [PASS|WARN|BLOCK|SKIP|TIMEOUT]

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
- TIMEOUT agents are noted but do not block the commit
- The last two lines must always be `COMMIT_VERDICT: PASS`, `COMMIT_VERDICT: BLOCK`, or `COMMIT_VERDICT: WARN` followed by `BLOCK_REASON`
- Do not ask questions — this is non-interactive
- Do not offer test generation — that's for the interactive `/project:review` command
- Before reporting any finding, check `.mantaignore` if it exists — suppress any finding matching a rule in that file
- Use the project map to prioritize high_risk_files for deeper review
