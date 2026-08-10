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

### Step 1: Shallow pre-scan (fast signal detection)

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

### Step 2: Get staged changes

```bash
git diff --cached --name-only
git diff --cached --stat
```

If there are no staged changes, output `COMMIT_VERDICT: PASS` and exit.

**Token efficiency — do not load the diff body yourself.** The file list and stat are all the orchestrator needs for routing. Each review agent runs `git diff --cached` in its own context; pasting the diff into this context or into agent prompts tokenizes it once per agent on top of the agent's own read.

### Step 3: Agent timeout budgets

| Agent | Timeout | Rationale |
|-------|---------|-----------|
| security-sentinel (SHALLOW) | 45s | Fast pattern checks only |
| security-sentinel (DEEP) | 90s | Full SAST + dep audit |
| code-quality | 45s | Diff-based, should be fast |
| perf-analyzer | 30s | Signal-based |
| db-migration-guardian | 20s | Focused file set |

TIMEOUT agents are noted but do not block the commit.

### Step 4: Run agents in parallel

Use the Agent tool to run these agents simultaneously, applying trigger routing from Step 1:

- **security-sentinel**: Always run. Pass `SENTINEL_MODE` from shallow scan.
- **code-quality**: Always run. CRITICAL issues only (skip INFO).
- **perf-analyzer**: Always run. CRITICAL issues only.
- **db-migration-guardian**: Run only if `SKIP_DB_GUARDIAN: false` (migration files staged).

Provide project map context to each agent. Keep each agent prompt lean: the staged file list, routing flags (`SENTINEL_MODE`, severity filter), and the project-map fields — **never the diff body** (agents fetch it themselves).

### Step 5: Delegate synthesis to review-reporter

Do **not** apply suppressions, deduplicate findings, or assemble the verdict yourself — that logic lives in one place: the `review-reporter` agent (`.claude/agents/review-reporter.md`).

Invoke `review-reporter` via the Agent tool with:
- **Mode**: `commit`
- The full raw output of every agent that ran, plus each agent's status (`PASS`/`WARN`/`BLOCK`/`SKIP`/`TIMEOUT`)
- The staged file list from Step 2
- The `SHALLOW_SCAN:` / `SENTINEL_MODE:` lines from Step 1 (echoed into the output)
- Which agents were skipped and why

The reporter applies `.mantaignore` + inline `manta-ignore` suppressions, deduplicates, and returns the complete `=== CLAUDE PRE-COMMIT REVIEW ===` block ending in the `COMMIT_VERDICT:` line.

### Step 6: Relay the verdict

Output the review-reporter's result **verbatim** as your final output — the git hook parses it. Do not add anything after the verdict lines.

If review-reporter fails or times out, fail open with maximum visibility: output the raw agent statuses, then `COMMIT_VERDICT: WARN` and `BLOCK_REASON: review-reporter unavailable — findings not synthesized, review manually`.

### Rules

- Be fast — this runs on every commit
- CRITICAL findings block the commit (`COMMIT_VERDICT: BLOCK`)
- WARNING findings allow the commit but are shown prominently (`COMMIT_VERDICT: WARN`) — they will block at push time
- INFO findings never affect the verdict
- TIMEOUT agents are noted but do not block the commit
- The last two lines must always be `COMMIT_VERDICT: PASS`, `COMMIT_VERDICT: BLOCK`, or `COMMIT_VERDICT: WARN` followed by `BLOCK_REASON`
- Do not ask questions — this is non-interactive
- Do not offer test generation — that's for the interactive `/review` command
- Use the project map to prioritize high_risk_files for deeper review
