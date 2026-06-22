**Begin by outputting:** `[ Manta Enterprise — Review · 4 agents ]`

Run a pre-commit review on the staged changes. Orchestrate the 4 core review agents and produce a consolidated report.

## Instructions

You are the **Review Orchestrator**. Run each agent below in order and consolidate their findings into a final verdict.

### Step 0: Load suppressions

```bash
cat .mantaignore 2>/dev/null
```

Parse `.mantaignore` if present. Apply suppression rules to all agent findings before including them in the consolidated report: if a finding's file path matches the glob and the issue description contains the keyword, skip it silently. At the end of the report, note how many findings were suppressed and from which file if any were.

### Step 1: Gather Context

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

### Step 3: Consolidated Report

Output the following structured report:

```
╔══════════════════════════════════════════════════════════╗
║           CLAUDE CODE PRE-COMMIT REVIEW                  ║
╚══════════════════════════════════════════════════════════╝

Files reviewed: [N]
[list of files]

┌─────────────────────────────────────────────────────────┐
│ CODE QUALITY           [PASS|WARN|BLOCK]                 │
├─────────────────────────────────────────────────────────┤
│ [Critical findings if any]                               │
│ [Warning findings if any]                                │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ SECURITY SENTINEL      [PASS|WARN|BLOCK]                 │
├─────────────────────────────────────────────────────────┤
│ [Critical findings if any]                               │
│ [Warning findings if any]                                │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ PERF ANALYZER          [PASS|WARN|BLOCK]                 │
├─────────────────────────────────────────────────────────┤
│ [Critical findings if any]                               │
│ [Warning findings if any]                                │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ DB MIGRATION GUARDIAN  [PASS|WARN|BLOCK|SKIP]            │
├─────────────────────────────────────────────────────────┤
│ [Critical findings if any, or "No migrations staged"]    │
└─────────────────────────────────────────────────────────┘

══════════════════════════════════════════════════════════
CRITICAL ISSUES (must fix before commit):
[Numbered list of all CRITICAL findings across all agents]
[Or "None" if clean]

WARNINGS (should fix soon):
[Numbered list of all WARNING findings across all agents]
[Or "None"]

INFO (optional improvements):
[Numbered list of INFO items]
[Or "None"]
══════════════════════════════════════════════════════════

OVERALL VERDICT: ✅ PASS | ⚠️ PASS WITH WARNINGS | 🚫 BLOCKED

[If BLOCKED]: Fix the [N] critical issue(s) above, then commit again.
  → Run /project:fix for AI-generated fix suggestions.
[If PASS WITH WARNINGS]: Commit allowed. Warnings will block at push time — run /project:fix to address them.
[If PASS]: Commit looks good.
══════════════════════════════════════════════════════════

COMMIT_VERDICT: PASS | WARN | BLOCK
```

The final line `COMMIT_VERDICT: PASS` or `COMMIT_VERDICT: BLOCK` is machine-readable and used by the git hook.

### Step 4: Documentation Update

After the review (regardless of verdict), check if doc-keeper should update docs:
- If new features were added: update CHANGELOG and possibly README
- If APIs changed: README may need updating
- Ask the user: "Should I update CHANGELOG.md and README.md with these changes? [Y/n]"
