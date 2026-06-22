**Begin by outputting:** `[ Manta Enterprise — Pre-Push Review ]`

Non-interactive pre-push review for use by the git pre-push hook. Reviews the full branch diff and outputs a machine-readable verdict.

Runs 3–4 agents. security-sentinel, code-quality, and perf-analyzer always run. db-migration-guardian is trigger-routed — only runs if migration files are present in the diff.

## Instructions

### Step 1: Load suppressions

```bash
cat .mantaignore 2>/dev/null
```

Parse `.mantaignore` if present (skip `#` lines and blanks). Apply suppression rules to all agent findings before including them in the output: if a finding's file path matches the glob and the issue description contains the keyword, skip it silently.

### Step 2: Get branch diff

```bash
git diff $REMOTE_SHA $LOCAL_SHA --name-only
git diff $REMOTE_SHA $LOCAL_SHA
```

If there are no changes, output `PUSH_VERDICT: PASS` and exit.

### Step 2.5: Compute routing signals

```bash
# Check for migration files in the diff
HAS_MIGRATION_FILES=$(git diff $REMOTE_SHA $LOCAL_SHA --name-only | grep -E '(migration|migrate|schema\.prisma|\.sql$)' | head -1 || true)
```

Set `SKIP_DB_GUARDIAN=true` if `$HAS_MIGRATION_FILES` is empty.

### Step 3: Run agents in parallel

Use the Agent tool to run the active agents simultaneously against the full branch diff. Apply trigger routing from Step 2.5.

- **security-sentinel**: always run — full security check: secrets, injection, auth, OWASP Top 10
- **code-quality**: always run — CRITICAL quality issues only (skip INFO)
- **perf-analyzer**: always run — CRITICAL performance issues only (N+1, blocking async, memory leaks)
- **db-migration-guardian**: run only if `SKIP_DB_GUARDIAN=false` (migration files detected in diff)

### Step 4: Output structured result

Output EXACTLY in this format (the git hook parses this):

```
=== CLAUDE PRE-PUSH REVIEW ===

CHANGED FILES:
[list of changed files]

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

PUSH_VERDICT: PASS
```

OR if there are critical issues:

```
PUSH_VERDICT: BLOCK
BLOCK_REASON: [N critical issues found — see above]
```

OR if there are warnings but no critical issues:

```
PUSH_VERDICT: WARN
BLOCK_REASON: [N warnings found — see above]
```

### Rules

- Do not ask questions — this is non-interactive
- `PUSH_VERDICT: BLOCK` for CRITICAL issues, `PUSH_VERDICT: WARN` for warnings only
- The last two lines must always be one of the three verdict formats above
- SKIP agents that have no relevant input (no migrations)
