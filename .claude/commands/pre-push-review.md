**Begin by outputting:** `[ Manta — Pre-Push Review ]`

Non-interactive pre-push review for use by the git pre-push hook. Reviews the full branch diff and outputs a machine-readable verdict.

Runs 3–4 agents. security-sentinel, code-quality, and perf-analyzer always run. db-migration-guardian is trigger-routed — only runs if migration files are present in the diff.

## Instructions

### Step 2: Get branch diff

```bash
git diff $REMOTE_SHA $LOCAL_SHA --name-only
git diff $REMOTE_SHA $LOCAL_SHA --stat
```

If there are no changes, output `PUSH_VERDICT: PASS` and exit.

**Token efficiency — do not load the diff body yourself.** The file list and stat are all the orchestrator needs for routing. Each review agent runs the diff command in its own context; pasting the diff here or into agent prompts tokenizes it once per agent on top of the agent's own read.

### Step 2.5: Compute routing signals

Run the shallow scanner against the branch diff — the detection regexes live in one place, `scripts/shallow-scan.sh`, not here:

```bash
bash scripts/shallow-scan.sh --range "$REMOTE_SHA..$LOCAL_SHA" || true
```

Read `SKIP_DB_GUARDIAN` from its output (also persisted to `.manta-cache/scan-signals.env`): `true` means no migration files in the diff.

### Step 3: Run agents in parallel

Use the Agent tool to run the active agents simultaneously against the full branch diff. Apply trigger routing from Step 2.5. Keep each agent prompt lean: the changed file list, the diff range (`$REMOTE_SHA..$LOCAL_SHA`), routing flags, and project-map fields — **never the diff body** (agents fetch it themselves).

- **security-sentinel**: always run — full security check: secrets, injection, auth, OWASP Top 10
- **code-quality**: always run — CRITICAL quality issues only (skip INFO)
- **perf-analyzer**: always run — CRITICAL performance issues only (N+1, blocking async, memory leaks)
- **db-migration-guardian**: run only if `SKIP_DB_GUARDIAN=false` (migration files detected in diff)

### Step 4: Delegate synthesis to review-reporter

Do **not** apply suppressions, deduplicate findings, or assemble the verdict yourself — that logic lives in one place: the `review-reporter` agent (`.claude/agents/review-reporter.md`).

Invoke `review-reporter` via the Agent tool with:
- **Mode**: `push`
- The full raw output of every agent that ran, plus each agent's status (`PASS`/`WARN`/`BLOCK`/`SKIP`)
- The changed file list from Step 2
- Which agents were skipped and why (routing flags from Step 2.5)

The reporter applies `.mantaignore` + inline `manta-ignore` suppressions, deduplicates findings across agents, and returns the complete `=== CLAUDE PRE-PUSH REVIEW ===` block ending in the `PUSH_VERDICT:` line.

### Step 5: Relay the verdict

Output the review-reporter's result **verbatim** as your final output — the git hook parses it. Do not add anything after the verdict lines.

If review-reporter fails or times out, fail closed (push-time blocks on warnings by design): output the raw agent statuses, then `PUSH_VERDICT: WARN` and `BLOCK_REASON: review-reporter unavailable — findings not synthesized, review manually`.

### Rules

- Do not ask questions — this is non-interactive
- `PUSH_VERDICT: BLOCK` for CRITICAL issues, `PUSH_VERDICT: WARN` for warnings only
- The last two lines must always be one of the three verdict formats
- SKIP agents that have no relevant input (no migrations)
