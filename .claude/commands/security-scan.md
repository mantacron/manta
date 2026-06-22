**Begin by outputting:** `[ Manta Enterprise — Security Scan ]`

Run a security audit of the entire repository — secrets, injection vulnerabilities, and OWASP Top 10 checks.

## Instructions

### Step 1: Full codebase secrets scan

Search for potential secrets across all files:

```bash
# Scan for common secret patterns
grep -r --include="*.ts" --include="*.js" --include="*.py" --include="*.go" --include="*.env" --include="*.yaml" --include="*.yml" --include="*.json" \
  -E "(password|secret|api_key|apikey|token|private_key)\s*=\s*['\"][^'\"]{8,}" \
  --exclude-dir=node_modules --exclude-dir=.git \
  . 2>/dev/null

# Scan for AWS keys
grep -r -E "AKIA[0-9A-Z]{16}" --exclude-dir=node_modules --exclude-dir=.git . 2>/dev/null

# Scan for private keys
grep -r "BEGIN.*PRIVATE KEY" --exclude-dir=node_modules --exclude-dir=.git . 2>/dev/null

# Scan for high-entropy strings (potential tokens)
grep -r -E "['\"][A-Za-z0-9+/]{40,}['\"]" --include="*.ts" --include="*.js" --include="*.py" --exclude-dir=node_modules --exclude-dir=.git . 2>/dev/null | head -50
```

### Step 2: Run security-sentinel on all source files

Use the **security-sentinel** agent to review the full codebase, not just recent changes.
Focus on:
- All API route handlers
- All authentication/authorization code
- All database query code
- All file system operations
- All external HTTP calls

### Step 3: Configuration security

```bash
# Check for insecure configurations
grep -r "debug.*true\|DEBUG.*=.*true" --include="*.json" --include="*.yaml" --include="*.yml" --exclude-dir=node_modules . 2>/dev/null

# Check for open CORS
grep -r "origin.*\*\|allowOrigin.*\*" --include="*.ts" --include="*.js" --include="*.py" --exclude-dir=node_modules . 2>/dev/null

# Check .gitignore has sensitive files covered
cat .gitignore 2>/dev/null
```

### Step 4: Report

Output a security report:

```
=== SECURITY AUDIT ===

Date: [today]
Scope: Full repository

SECRETS SCAN:
[Findings or "Clean"]

CODE SECURITY REVIEW:
[Findings from security-sentinel]

CONFIGURATION:
[Findings or "Clean"]

SUMMARY:
Critical: [N]
High: [N]
Medium: [N]
Low: [N]

SECURITY_POSTURE: CLEAN | NEEDS_ATTENTION | CRITICAL_ISSUES
=== END AUDIT ===
```

### Step 5: Generate remediation plan (if issues found)

If there are any CRITICAL or HIGH findings, generate a prioritized remediation plan:

```
REMEDIATION PRIORITY:
1. [Most critical issue] — fix by [immediate/this sprint/next sprint]
2. ...
```

### Step 6: Save report to disk

```bash
mkdir -p reports
```

Write the full report to: `reports/YYYY-MM-DD-security-scan.md`

If a report for today already exists, append a counter: `reports/YYYY-MM-DD-2-security-scan.md`.

Tell the user:
> "Security scan complete. Report saved to `reports/[filename]`."

### Step 7: Next Steps

```
Next steps:
  CLEAN             → /project:audit             include in full health report
  NEEDS_ATTENTION   → /project:fix               get fix suggestions for flagged files
  CRITICAL_ISSUES   → address immediately before any commits or releases
```
