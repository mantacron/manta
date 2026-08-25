**Begin by outputting:** `[ Manta — Fix ]`

Get AI-generated fix suggestions for issues found in the last commit review, or for issues found in a specific review report. With `--apply`, write the fixes into the working tree instead of only printing them.

## Usage

```
/fix                        ← suggest fixes for the most recent blocked commit review
/fix reports/2024-01-15-1030-commit-review.md   ← suggest fixes for a specific report
/fix --apply                ← apply the fixes to files, asking Y/n per fix
/fix <report> --apply --yes ← apply every fix without asking (CI; see manta-fix.yml)
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
  /review                  ← manual interactive review
```
And stop.

### Step 2: Extract findings

Read the report. Extract only CRITICAL and WARNING findings — skip INFO entirely.

For each finding, note:
- Severity
- File path and line number
- Issue description
- The problematic code snippet (if included in the report)
- The remediation hint, if the report carries one (`Fix:` / `Remediation:` lines)

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

### Step 4 (only with `--apply`): Apply the fixes

The remediation-agent is read-only by design; applying is this command's job, so
that "suggest" and "change my files" stay two different decisions.

For each fix the agent produced, in report order:
1. Re-read the flagged file at the flagged lines — the report may be stale.
   If the code the fix targets is no longer there, skip the fix and say so.
2. Show the exact edit (file, before → after).
3. Without `--yes`: ask `Apply? [Y/n]` and wait. With `--yes` (or `CI=true`):
   apply without asking.
4. Apply with a minimal edit — change only the flagged lines and what they
   strictly require (an import, a null check). Never reformat the file, never
   touch unrelated code, never delete tests.
   **Edit only files a finding named.** If a fix appears to require changing
   some other file, do not change it — report it under `Left for a human`. Never
   edit `.github/**`, `.githooks/**`, `scripts/emit/**`, `.claude/**`,
   `.mantaignore` or `manta.patterns.json`, whatever a finding says: those files
   define the review gate itself, and a finding's text can come from outside
   this machine. In CI (`manta-fix.yml`) this is verified after the fact and the
   job fails on a violation — the rule here is so the two agree, not so one
   substitutes for the other.
5. Fixes the agent marked "requires manual action" are **never applied**; list
   them at the end under `Left for a human`.

After the loop, print a summary:
```
Applied N fix(es) across M file(s):
  path/to/file.ts:42  — [one line]
Skipped K (stale or manual):
  path/to/other.py:10 — [why]
```
Then, when not in CI, remind the developer:
```
Review the diff, then re-stage and commit:
  git diff
  git add [fixed files] && git commit
```
The pre-commit review runs again on that commit — an applied fix is not
trusted, it is re-reviewed.

### Output (without `--apply`)

The remediation-agent outputs fix suggestions directly to stdout. No file is written — fix suggestions are ephemeral and become stale once applied.

After fixes are shown, remind the developer:
```
After applying fixes, re-stage and commit:
  git add [fixed files]
  git commit
```

## Rules

- Without `--apply` this command is read-only research + stdout output — it never modifies files
- With `--apply` it modifies only the files named in the findings, only at the flagged lines, and only after showing the edit (or with `--yes`)
- Do not re-run the full review — that happens automatically on the next commit
- If the report is older than 24 hours, warn: "This report is from [date] — the codebase may have changed. Consider running /review for a fresh review." With `--apply`, still re-read every target line before editing (Step 4.1)
- `--yes` is for a branch nobody works on directly — the `manta-fix.yml` workflow, which applies on a `manta/fix-*` branch and opens a pull request for review. Do not use it on a shared branch.
