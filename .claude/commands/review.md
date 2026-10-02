**Begin by outputting:** `[ Manta — Review · 4 agents ]`

Run a pre-commit review on the staged changes — or, with `--range A..B`
(e.g. `--range origin/main..HEAD`), on commits you have made but not pushed.
Orchestrate the 4 core review agents and produce a consolidated report.

---

## Review Depth

Accepts `--depth=quick|standard|deep` (default: `standard`). Depth sets the **budget
and rigor** of each agent — it does not change *which* agents run (that is trigger
routing, decided separately).

| Depth | Full-file reads/agent | Findings reported | Severities | Model override |
|-------|----------------------|-------------------|------------|----------------|
| `quick` | ≤5, grep-first only | top 5 per severity | CRITICAL in full; each WARNING as one line | `sonnet` for every agent |
| `standard` | ≤15 | top 10 per severity | CRITICAL + WARNING | agent default (frontmatter) |
| `deep` | ≤50, trace data flow across files | all findings, no truncation | CRITICAL + WARNING + INFO | `opus` for analysis agents |

Pass the resolved caps into every agent prompt as `READ_CAP` and `FINDING_CAP`, and
pass the model override (when the depth defines one) as the Agent tool's `model`
parameter, which takes precedence over the agent's frontmatter.


## Instructions

You are the **Review Orchestrator**. Run each agent below and hand their findings to `review-reporter` for the final consolidated report.

### Step 1: Gather Context

The scope is the staged changes, unless `$ARGUMENTS` contains `--range A..B`;
then it is that commit range, and every `git diff --cached` below — in your
commands and in each agent's prompt — becomes `git diff A B` (tell each agent the
exact command). Check the range resolves first (`git rev-parse --verify A B`);
if it does not, say so and stop. With nothing staged and no range, say
"Nothing staged — stage files, or pass --range origin/main..HEAD to review
unpushed commits" and stop.

```bash
git diff --cached --name-only
git diff --cached --stat
git diff --cached
```

Read each changed file completely for context.

### Step 2: Run All Agents

Run these agents by using the Agent tool with the appropriate subagent_type and prompt:

1. **code-quality** — Review code quality, DRY, edge cases, naming
2. **security-sentinel** — Full security audit + dependency scan
3. **perf-analyzer** — Performance bottleneck detection
4. **db-migration-guardian** — Migration safety checks; skips if no migration files staged

You can run agents 1-4 in parallel since they're independent.

### Step 3: Delegate synthesis to review-reporter

Do **not** apply suppressions, deduplicate findings, or assemble the report yourself — that logic lives in one place: the `review-reporter` agent (`.claude/agents/review-reporter.md`).

Invoke `review-reporter` via the Agent tool with:
- **Mode**: `interactive`
- The full raw output of every agent that ran, plus each agent's status (`PASS`/`WARN`/`BLOCK`/`SKIP`)
- The staged file list from Step 1, in the agent order above (for the per-agent report boxes)
- Which agents were skipped and why

The reporter applies `.mantaignore` + inline `manta-ignore` suppressions, deduplicates findings across agents, and assembles the consolidated boxed report ending in the `COMMIT_VERDICT:` line.

Relay the reporter's full output to the user. The final line `COMMIT_VERDICT: PASS` or `COMMIT_VERDICT: BLOCK` is machine-readable and used by the git hook.

### Step 4: Documentation Update

After the review (regardless of verdict), check if doc-keeper should update docs:
- If new features were added: update CHANGELOG and possibly README
- If APIs changed: README may need updating
- Then, as the last thing the run prints, ask:
  "Should I update CHANGELOG.md and README.md with these changes? [Y/n]
  Without an answer nothing is written — the same later: /update-docs"
- `--yes` (or `MANTA_ASSUME=yes`) answers yes without asking; `--no` (or
  `MANTA_ASSUME=no`) skips it. In a headless run (`claude -p`, CI) with neither,
  nothing is written and the question above is the run's final line, so the
  person reading the log knows exactly what to run.
