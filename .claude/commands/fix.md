**Begin by outputting:** `[ Manta — Fix ]`

Get AI-generated fix suggestions for issues found in the last commit review, or for issues found in a specific review report.

## Usage

```
/project:fix                        ← fix issues from the most recent blocked commit review
/project:fix reports/2024-01-15-1030-commit-review.md   ← fix issues from a specific report
```

## Instructions

### Step 1: Find the findings

If a report path was passed as an argument, read that file.

Otherwise, find the most recent commit review report:
```bash
ls -t reports/*-commit-review.md 2>/dev/null | head -1
```

If no commit review reports exist, check for push review reports:
```bash
ls -t reports/*-push-review.md 2>/dev/null | head -1
```

If no reports exist at all, output:
```
No review reports found in reports/. Run a review first:
  git add [files] && git commit   ← triggers pre-commit review
  /project:review                  ← manual interactive review
```
And stop.

### Step 2: Extract findings

Read the report. Extract only CRITICAL and WARNING findings — skip INFO entirely.

For each finding, note:
- Severity
- File path and line number
- Issue description
- The problematic code snippet (if included in the report)

If the report has no CRITICAL or WARNING findings, output:
```
No CRITICAL or WARNING findings in [report path]. Nothing to fix.
```
And stop.

### Step 3: Run remediation-agent

Pass the extracted findings to the remediation-agent. The agent will:
- Read only the flagged files/lines (not the full codebase)
- Generate concrete, copy-paste-ready fixes
- Flag anything requiring manual action

### Output

The remediation-agent outputs fix suggestions directly to stdout. No file is written — fix suggestions are ephemeral and become stale once applied.

After fixes are shown, remind the developer:
```
After applying fixes, re-stage and commit:
  git add [fixed files]
  git commit
```

## Rules

- This command is read-only research + stdout output only — it never modifies files
- Fixes are suggestions only — the developer applies them manually
- Do not re-run the full review — that happens automatically on the next commit
- If the report is older than 24 hours, warn: "This report is from [date] — the codebase may have changed. Consider running /project:review for a fresh review."
