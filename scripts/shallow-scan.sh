#!/usr/bin/env bash
# Shallow pre-scan — runs in ~2-5 seconds before full agent review.
# Checks a diff for high-signal security and quality patterns, plus the
# routing signals (migrations, API routes, new symbols) that decide which
# agents run. This is the single home of these detection regexes — the
# pre-commit and pre-push orchestrators both read this script's output
# instead of keeping their own divergent copies.
# Outputs a structured signal report; exits 0 (clean) or 1 (signals found).
# Also persists all signals to .manta-cache/scan-signals.env for reuse.
#
# Usage:
#   bash scripts/shallow-scan.sh                          # staged diff (pre-commit)
#   bash scripts/shallow-scan.sh --range REMOTE..LOCAL    # branch diff (pre-push)

set -euo pipefail

# ─── Parse args ───────────────────────────────────────────────────────────────
DIFF_RANGE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --range) DIFF_RANGE="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

CACHE_DIR=".manta-cache"
SIGNALS_FILE="$CACHE_DIR/scan-signals.env"

# ─── Collect diff ─────────────────────────────────────────────────────────────
if [[ -n "$DIFF_RANGE" ]]; then
  SCAN_DIFF=$(git diff "$DIFF_RANGE" 2>/dev/null || echo "")
  SCAN_FILES=$(git diff "$DIFF_RANGE" --name-only 2>/dev/null || echo "")
else
  SCAN_DIFF=$(git diff --cached 2>/dev/null || echo "")
  SCAN_FILES=$(git diff --cached --name-only 2>/dev/null || echo "")
fi

if [[ -z "$SCAN_DIFF" ]]; then
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

# Helper: grep staged diff for pattern, increment counter and log matches.
# Pass "-i" as the 4th arg for case-insensitive matching (credential names are
# often SCREAMING_CASE constants — DB_PASS, API_KEY — not the lowercase words
# the pattern spells out).
scan() {
  local label="$1"
  local pattern="$2"
  local counter_var="$3"
  local case_flag="${4:-}"
  local matches
  matches=$(echo "$SCAN_DIFF" | grep -E "^\+" | grep -Ev "^\+\+\+" | grep -E $case_flag -- "$pattern" | head -5 || true)
  if [[ -n "$matches" ]]; then
    eval "$counter_var=\$((\$$counter_var + 1))"
    SIGNALS_DETAIL+="  [$label] $(echo "$matches" | head -2 | sed 's/^/    /')\n"
  fi
}

# ─── Secret patterns ──────────────────────────────────────────────────────────
scan "SECRET" '(password|secret|api_key|apikey|token|private_key)\s*=\s*["\x27][^"$\x27]{8,}' "SECRETS" -i
scan "SECRET" '(sk_live_|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|xoxb-|AIza[A-Za-z0-9_-]{35})' "SECRETS"
scan "SECRET" '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY' "SECRETS"
scan "SECRET" '["'"'"'][A-Za-z0-9+/]{40,}={0,2}["'"'"']' "SECRETS"
# PHP/Ruby/Java-style constant declarations: define('DB_PASS', '...'), const API_KEY = "..."
scan "SECRET" '(define\(\s*["'"'"']|const\s+)\w*(PASS|SECRET|API_KEY|TOKEN|PRIVATE_KEY)\w*["'"'"']?\s*[,=]\s*["'"'"'][^"'"'"']{6,}' "SECRETS" -i

# ─── Injection sinks ──────────────────────────────────────────────────────────
scan "SQLI"   'cursor\.execute\(f["'"'"']|execute\(".*"\s*%\s*\w|execute\(".*"\s*\+\s*' "INJECTION"
# PHP/Perl-style string-interpolated or concatenated SQL: "SELECT ... $var" / "SELECT ..." . $var
# (deliberately lenient about quote style in the middle — PHP double-quoted
# strings routinely embed single-quoted variables, e.g. "...= '$userId'")
scan "SQLI"   '["'"'"'](SELECT|INSERT|UPDATE|DELETE)\b.{0,100}\$\w+' "INJECTION" -i
scan "SQLI"   '["'"'"'][^"'"'"']*\b(SELECT|INSERT|UPDATE|DELETE)\b[^"'"'"']*["'"'"']\s*\.\s*\$?\w+' "INJECTION" -i
scan "CMDI"   'subprocess\.(run|call|Popen).*shell\s*=\s*True|os\.system\(' "INJECTION"
scan "EVAL"   '\beval\s*\(|exec\s*\(' "INJECTION"
scan "XSS"    'innerHTML\s*=|dangerouslySetInnerHTML|document\.write\(' "INJECTION"
scan "SSTI"   'render_template_string\(|Markup\(' "INJECTION"

# ─── Weak crypto ──────────────────────────────────────────────────────────────
scan "CRYPTO" '\b(md5|sha1|sha-1|des|rc4)\s*[\(=]|hashlib\.md5|hashlib\.sha1' "CRYPTO"
scan "CRYPTO" 'Math\.random\(\)|random\.random\(\)|random\.randint\(' "CRYPTO"
scan "CRYPTO" 'Digest::(MD5|SHA1)|MessageDigest\.getInstance\(["'"'"'](MD5|SHA-?1)["'"'"']' "CRYPTO"

# ─── Quality signals (DRY, complexity hints) ─────────────────────────────────
scan "QUALITY" 'TODO|FIXME|HACK|XXX|NOSONAR' "QUALITY"

# ─── Migration file detection ─────────────────────────────────────────────────
MIGRATION_FILES=$(echo "$SCAN_FILES" | grep -E '(migration|migrate|schema\.prisma|\.sql$)' || true)
HAS_MIGRATIONS=""
[[ -n "$MIGRATION_FILES" ]] && HAS_MIGRATIONS="true"

# ─── Routing signals: new API routes and new symbols ─────────────────────────
# Used by pre-push to trigger-route observability-guardian and test-architect.
ADDED_LINES=$(echo "$SCAN_DIFF" | grep -E "^\+" | grep -Ev "^\+\+\+" || true)

HAS_API_ROUTES=""
echo "$ADDED_LINES" | grep -Eq "(router\.(get|post|put|delete|patch|use)\(|app\.(get|post|put|delete|patch|use)\(|@(Get|Post|Put|Delete|Patch|Route)\(|\.route\(|@app\.route|fastapi\.(get|post|put|delete)|express\.Router)" && HAS_API_ROUTES="true"

HAS_NEW_SYMBOLS=""
echo "$ADDED_LINES" | grep -Eq "^\+(def |async def |function |class |export (default |async )?function|public (static |async )?(void|[A-Z][a-zA-Z]+))" && HAS_NEW_SYMBOLS="true"

# ─── Zero-trust surface detection ────────────────────────────────────────────
# zero-trust-guardian has the largest agent prompt of the push set, so route it
# like the others rather than running it on every push. Trigger on anything that
# can move a trust boundary: IaC and orchestration manifests, IAM/RBAC/policy
# files, service-mesh config, auth code, or new API routes — its universal check
# is "auth on every endpoint", so new routes must still reach it.
INFRA_FILES=$(echo "$SCAN_FILES" | grep -Ei '(dockerfile|docker-compose|\.tf$|\.tfvars$|(^|/)k8s/|(^|/)kubernetes/|(^|/)helm/|(chart|deployment|service|ingress|role|rolebinding)\.ya?ml$|iam|rbac|istio|linkerd|serviceaccount|\.github/workflows/)' || true)
AUTH_FILES=$(echo "$SCAN_FILES" | grep -Ei '(auth|login|session|token|jwt|oauth|permission|policy|acl|middleware)' || true)
HAS_ZERO_TRUST_SURFACE=""
{ [[ -n "$INFRA_FILES" ]] || [[ -n "$AUTH_FILES" ]] || [[ -n "$HAS_API_ROUTES" ]]; } && HAS_ZERO_TRUST_SURFACE="true"

# ─── Spec/constitution file presence ─────────────────────────────────────────
HAS_SPEC=""
{ [[ -f "spec/SPEC.md" ]] || [[ -f "../spec/SPEC.md" ]]; } && HAS_SPEC="true"
HAS_CONSTITUTION=""
{ [[ -f "CONSTITUTION.md" ]] || [[ -f "../CONSTITUTION.md" ]]; } && HAS_CONSTITUTION="true"

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

SKIP_OBSERVABILITY="true"
[[ -n "$HAS_API_ROUTES" ]] && SKIP_OBSERVABILITY="false"

SKIP_TEST_ARCHITECT="true"
[[ -n "$HAS_NEW_SYMBOLS" ]] && SKIP_TEST_ARCHITECT="false"

SKIP_ZERO_TRUST="true"
[[ -n "$HAS_ZERO_TRUST_SURFACE" ]] && SKIP_ZERO_TRUST="false"

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
echo "SKIP_OBSERVABILITY: $SKIP_OBSERVABILITY"
echo "SKIP_TEST_ARCHITECT: $SKIP_TEST_ARCHITECT"
echo "SKIP_ZERO_TRUST: $SKIP_ZERO_TRUST"
echo "HAS_MIGRATIONS: ${HAS_MIGRATIONS:-false}"
echo "HAS_SPEC: ${HAS_SPEC:-false}"
echo "HAS_CONSTITUTION: ${HAS_CONSTITUTION:-false}"
echo "HAS_API_ROUTES: ${HAS_API_ROUTES:-false}"
echo "HAS_NEW_SYMBOLS: ${HAS_NEW_SYMBOLS:-false}"
echo "HAS_ZERO_TRUST_SURFACE: ${HAS_ZERO_TRUST_SURFACE:-false}"

# ─── Persist signals for downstream reuse ─────────────────────────────────────
mkdir -p "$CACHE_DIR" 2>/dev/null || true
cat > "$SIGNALS_FILE" << EOF
SCAN_GENERATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SCAN_RANGE=${DIFF_RANGE:-staged}
SIGNALS=$TOTAL_SIGNALS
SECRETS=$SECRETS
INJECTION=$INJECTION
CRYPTO=$CRYPTO
QUALITY=$QUALITY
SENTINEL_MODE=$SENTINEL_MODE
SKIP_DB_GUARDIAN=$SKIP_DB_GUARDIAN
SKIP_SPEC_GUARDIAN=$SKIP_SPEC_GUARDIAN
SKIP_COMPLIANCE=$SKIP_COMPLIANCE
SKIP_OBSERVABILITY=$SKIP_OBSERVABILITY
SKIP_TEST_ARCHITECT=$SKIP_TEST_ARCHITECT
SKIP_ZERO_TRUST=$SKIP_ZERO_TRUST
HAS_MIGRATIONS=${HAS_MIGRATIONS:-false}
HAS_SPEC=${HAS_SPEC:-false}
HAS_CONSTITUTION=${HAS_CONSTITUTION:-false}
HAS_API_ROUTES=${HAS_API_ROUTES:-false}
HAS_NEW_SYMBOLS=${HAS_NEW_SYMBOLS:-false}
EOF

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
