**Begin by outputting:** `[ Manta — Pre-Commit Review ]`

Non-interactive pre-commit review for use by the git pre-commit hook. Reviews staged changes and outputs a machine-readable verdict.

Runs 3 agents — and only the ones where **the commit itself is the harm**.

A secret reaches history the moment it is committed and needs a rotation and a
rewrite to remove; a logic bug that crashes is cheapest to catch before it
lands; an unsafe migration is dangerous to run. Those block here.

Everything else waits for push, where the same agents review the whole branch
diff, and for the PR job in CI. Performance is the clearest case: nothing about
a regression gets worse for sitting in a local commit, and `perf-analyzer`
passed 25 of 26 commit reviews while producing one CRITICAL in 27 — so it costs
~85k tokens per commit to re-answer a question push already asks. Spec
alignment, test coverage, compliance and observability were moved out for the
same reason (see pre-push-review.md).

## Instructions

### Step 0: Read what the hook already gathered — do not re-run it

**When this prompt begins with a `## Shallow Pre-Scan Results` block, the git
hook has already run `shallow-scan.sh` and `build-project-map.sh`. Read the
block. Do not run either script yourself.**

Running them again is the single most expensive mistake available here. Each of
your turns re-sends the whole context — roughly 50k tokens — so two redundant
Bash calls cost about 100k tokens to recompute a result already sitting in your
prompt. Measured on the demo fixture: they were 20% of the orchestrator's entire
bill, and the orchestrator is ~70% of what a commit costs.

The block gives you:
- `SHALLOW_SCAN: CLEAN` — no high-risk signals; run security-sentinel in SHALLOW mode (pattern checks only, skip taint analysis and dep audit)
- `SHALLOW_SCAN: SIGNALS_FOUND` — run security-sentinel in DEEP mode
- `SENTINEL_MODE: SHALLOW|DEEP` — pass this to security-sentinel directly
- `SKIP_DB_GUARDIAN: true` — skip db-migration-guardian (no migration files staged)

The project map is at `.manta-cache/project-map.json`, freshly built by the
hook. Read it only if you need `high_risk_files` for routing — its contents go
to the agents as context so they don't re-scan the repo.

Only when the block is **absent** — you were invoked interactively rather than
by the hook — run the two scripts yourself:

```bash
bash scripts/build-project-map.sh 2>/dev/null || true
bash scripts/shallow-scan.sh 2>/dev/null
```

### Step 1: Get staged changes

One call, not two:

```bash
git diff --cached --name-only; echo "---STAT---"; git diff --cached --stat
```

If there are no staged changes, output `COMMIT_VERDICT: PASS` and exit.

### Step 2: Your own turn budget

You are routing, not reviewing. A commit's cost is dominated by *your* turns,
because each one re-sends the full context — so the budget that matters is the
number of times you stop to think.

**At most five tool calls**: one Bash for Step 1, two or three parallel `Agent`
calls in a single message, one `Agent` call for review-reporter. Nothing else. In
particular:

- Do not read the diff body, source files, or agent definitions.
- Do not schedule wakeups, poll for agent completion, or call any tool other
  than `Bash` and `Agent` — agent results arrive on their own.
- Do not verify or re-derive an agent's findings; that is review-reporter's job.

**Token efficiency — do not load the diff body yourself.** The file list and stat are all the orchestrator needs for routing. Each review agent runs `git diff --cached` in its own context; pasting the diff into this context or into agent prompts tokenizes it once per agent on top of the agent's own read.

### Step 3: Agent timeout budgets

| Agent | Timeout | Rationale |
|-------|---------|-----------|
| security-sentinel (SHALLOW) | 45s | Fast pattern checks only |
| security-sentinel (DEEP) | 90s | Full SAST + dep audit |
| code-quality | 45s | Diff-based, should be fast |
| db-migration-guardian | 20s | Focused file set, and only when a migration is staged |

TIMEOUT agents are noted but do not block the commit.

### Step 4: Run agents in parallel

Use the Agent tool to run these agents simultaneously, applying trigger routing from Step 0. Dispatch all of them in a **single message** — separate messages cost a full context re-send each:

- **security-sentinel**: Always run. Pass `SENTINEL_MODE` from shallow scan.
- **code-quality**: Always run. CRITICAL issues only (skip INFO).
- **db-migration-guardian**: Run only if `SKIP_DB_GUARDIAN: false` (migration files staged).

`perf-analyzer` is deliberately **not** here — it runs at push and in the PR job.
Do not add it back without the numbers to justify it.

Provide project map context to each agent. Keep each agent prompt lean: the staged file list, routing flags (`SENTINEL_MODE`, severity filter), and the project-map fields — **never the diff body** (agents fetch it themselves).

State `mode: commit` in every agent prompt. That word activates the **Review
Scope** contract in the agent definitions: staged diff only, every finding
anchored to a touched line, a 20-tool-call ceiling, and no test runs, builds,
hook executions, or submodule descents. Whole-project sweeps belong to `/audit`
— this gate runs on every commit and is priced accordingly.

### Step 5: Delegate synthesis to review-reporter

Do **not** apply suppressions, deduplicate findings, or assemble the verdict yourself — that logic lives in one place: the `review-reporter` agent (`.claude/agents/review-reporter.md`).

Invoke `review-reporter` via the Agent tool with:
- **Mode**: `commit`
- The full raw output of every agent that ran, plus each agent's status (`PASS`/`WARN`/`BLOCK`/`SKIP`/`TIMEOUT`)
- The staged file list from Step 1
- The `SHALLOW_SCAN:` / `SENTINEL_MODE:` lines from Step 0 (echoed into the output)
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
