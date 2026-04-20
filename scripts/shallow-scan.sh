#!/usr/bin/env bash
# Shallow pre-scan — runs in ~2-5 seconds before full agent review.
# Checks staged changes for high-signal security and quality patterns.
# Outputs a structured signal report; exits 0 (clean) or 1 (signals found).
#
# Usage: bash scripts/shallow-scan.sh [--diff "git diff output"] [--files "file list"]
# Called by pre-commit hook before invoking Claude agents.

set -euo pipefail

# ─── Collect staged diff ──────────────────────────────────────────────────────
STAGED_DIFF=$(git diff --cached 2>/dev/null || echo "")
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null || echo "")

if [[ -z "$STAGED_DIFF" ]]; then
  echo "SHALLOW_SCAN: CLEAN"
  echo "SIGNALS: 0"
  exit 0
fi

# ─── Signal counters ──────────────────────────────────────────────────────────
SECRETS=0
INJECTION=0
CRYPTO=0
QUALITY=0
SIGNALS_DETAIL=""

# Helper: grep staged diff for pattern, increment counter and log matches
scan() {
  local label="$1"
  local pattern="$2"
  local counter_var="$3"
  local matches
  matches=$(echo "$STAGED_DIFF" | grep -E "^\+" | grep -v "^\+\+\+" | grep -E "$pattern" | head -5 || true)
  if [[ -n "$matches" ]]; then
    eval "$counter_var=\$((\$$counter_var + 1))"
    SIGNALS_DETAIL+="  [$label] $(echo "$matches" | head -2 | sed 's/^/    /')\n"
  fi
}

# ─── Secret patterns ──────────────────────────────────────────────────────────
scan "SECRET" '(password|secret|api_key|apikey|token|private_key)\s*=\s*["\x27][^"$\x27]{8,}' "SECRETS"
scan "SECRET" '(sk_live_|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|xoxb-|AIza[A-Za-z0-9_-]{35})' "SECRETS"
scan "SECRET" '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY' "SECRETS"
scan "SECRET" '["'"'"'][A-Za-z0-9+/]{40,}={0,2}["'"'"']' "SECRETS"

# ─── Injection sinks ──────────────────────────────────────────────────────────
scan "SQLI"   'cursor\.execute\(f["'"'"']|execute\(".*"\s*%\s*\w|execute\(".*"\s*\+\s*' "INJECTION"
scan "CMDI"   'subprocess\.(run|call|Popen).*shell\s*=\s*True|os\.system\(' "INJECTION"
scan "EVAL"   '\beval\s*\(|exec\s*\(' "INJECTION"
scan "XSS"    'innerHTML\s*=|dangerouslySetInnerHTML|document\.write\(' "INJECTION"
scan "SSTI"   'render_template_string\(|Markup\(' "INJECTION"

# ─── Weak crypto ──────────────────────────────────────────────────────────────
scan "CRYPTO" '\b(md5|sha1|sha-1|des|rc4)\s*[\(=]|hashlib\.md5|hashlib\.sha1' "CRYPTO"
scan "CRYPTO" 'Math\.random\(\)|random\.random\(\)|random\.randint\(' "CRYPTO"

# ─── Quality signals (DRY, complexity hints) ─────────────────────────────────
scan "QUALITY" 'TODO|FIXME|HACK|XXX|NOSONAR' "QUALITY"

# ─── Migration file detection ─────────────────────────────────────────────────
MIGRATION_FILES=$(echo "$STAGED_FILES" | grep -E '(migration|migrate|schema\.prisma|\.sql$)' || true)
HAS_MIGRATIONS=""
[[ -n "$MIGRATION_FILES" ]] && HAS_MIGRATIONS="true"

# ─── Spec/constitution file presence ─────────────────────────────────────────
HAS_SPEC=""
[[ -f "spec/SPEC.md" ]] || [[ -f "../spec/SPEC.md" ]] && HAS_SPEC="true"
HAS_CONSTITUTION=""
[[ -f "CONSTITUTION.md" ]] || [[ -f "../CONSTITUTION.md" ]] && HAS_CONSTITUTION="true"

# ─── Compute totals and determine agents to skip ─────────────────────────────
TOTAL_SIGNALS=$(( SECRETS + INJECTION + CRYPTO ))

# Agent routing decisions:
# - security-sentinel: always run (it's the primary gatekeeper); but go DEEP only if signals
# - code-quality: always run
# - perf-analyzer: always run (N+1 not detectable in shallow scan)
# - db-migration-guardian: only if migration files present

SKIP_DB_GUARDIAN="true"
[[ -n "$HAS_MIGRATIONS" ]] && SKIP_DB_GUARDIAN="false"

SKIP_SPEC_GUARDIAN="true"
[[ -n "$HAS_SPEC" ]] && SKIP_SPEC_GUARDIAN="false"

SKIP_COMPLIANCE="true"
[[ -n "$HAS_CONSTITUTION" ]] && SKIP_COMPLIANCE="false"

SENTINEL_MODE="SHALLOW"
[[ $TOTAL_SIGNALS -gt 0 ]] && SENTINEL_MODE="DEEP"

# ─── Output ───────────────────────────────────────────────────────────────────
if [[ $TOTAL_SIGNALS -eq 0 && $QUALITY -eq 0 ]]; then
  echo "SHALLOW_SCAN: CLEAN"
else
  echo "SHALLOW_SCAN: SIGNALS_FOUND"
fi

echo "SIGNALS: $TOTAL_SIGNALS"
echo "SECRETS: $SECRETS"
echo "INJECTION: $INJECTION"
echo "CRYPTO: $CRYPTO"
echo "QUALITY: $QUALITY"
echo "SENTINEL_MODE: $SENTINEL_MODE"
echo "SKIP_DB_GUARDIAN: $SKIP_DB_GUARDIAN"
echo "SKIP_SPEC_GUARDIAN: $SKIP_SPEC_GUARDIAN"
echo "SKIP_COMPLIANCE: $SKIP_COMPLIANCE"
echo "HAS_MIGRATIONS: ${HAS_MIGRATIONS:-false}"
echo "HAS_SPEC: ${HAS_SPEC:-false}"
echo "HAS_CONSTITUTION: ${HAS_CONSTITUTION:-false}"

if [[ -n "$SIGNALS_DETAIL" ]]; then
  echo ""
  echo "SIGNAL_DETAIL:"
  printf "%b" "$SIGNALS_DETAIL"
fi

# Exit 1 if any high-severity signals found (secrets or injection)
if [[ $SECRETS -gt 0 || $INJECTION -gt 0 ]]; then
  exit 1
fi
exit 0
