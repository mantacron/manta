#!/usr/bin/env bash
# Manta — Self-Test
#
# Mechanical health checks for this repo itself. No AI, no API key — runs in seconds.
# Community subset of the enterprise self-test: shell syntax, rebrand regressions,
# installer/inventory parity, an end-to-end installer run, and behavioral checks
# for shallow-scan detection, hook verdict parsing, and the project-map cache.
#
# Run locally:  bash scripts/self-test.sh
# Runs in CI:   .github/workflows/self-test.yml (every push and PR)

set -uo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

FAILURES=0

log_step() { echo -e "\n${CYAN}${BOLD}▶ $1${RESET}"; }
log_ok()   { echo -e "  ${GREEN}✓${RESET} $1"; }
log_fail() { echo -e "  ${RED}✗${RESET} $1"; ((FAILURES++)) || true; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo ""
echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}${BOLD}║              Manta — Self-Test                    ║${RESET}"
echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════╝${RESET}"

# ─── 1. Shell syntax ──────────────────────────────────────────────────────────
log_step "Shell syntax (bash -n)"

for f in scripts/*.sh .githooks/*; do
  if bash -n "$f" 2>/dev/null; then
    log_ok "$f"
  else
    log_fail "$f — syntax error"
    bash -n "$f" 2>&1 | head -3 | sed 's/^/      /'
  fi
done

# ─── 2. Banned tokens ─────────────────────────────────────────────────────────
# Regressions from the 2026-07 Cathy→Manta rename and the legacy /project:
# command syntax. These tokens must never reappear in tracked files.
log_step "Banned-token regression scan"

BANNED='\.cathyignore|cathy\.patterns\.json|CATHY_DIR|cathy-sast|\.cathy-cache|ui-ui-component|/project:|rpi:(research|plan|implement)'
EXCLUDES=(':(exclude)scripts/self-test.sh')

if git grep -nE "$BANNED" -- . "${EXCLUDES[@]}" > /dev/null 2>&1; then
  log_fail "banned tokens found (stale cathy naming or legacy /project: syntax):"
  git grep -nE "$BANNED" -- . "${EXCLUDES[@]}" | head -10 | sed 's/^/      /'
else
  log_ok "no stale cathy naming or legacy /project: syntax"
fi

# ─── 3. Inventory parity ──────────────────────────────────────────────────────
# Every agent/command in .claude/ must be listed in install.sh, or installs
# silently ship an incomplete pipeline (this exact bug shipped for weeks:
# install.sh listed 11 of 19 agents and 14 of 21 commands).
log_step "Inventory parity (.claude/ vs install.sh)"

repo_agents=$(ls .claude/agents/*.md | wc -l | tr -d ' ')
repo_commands=$(ls .claude/commands/*.md | wc -l | tr -d ' ')
installer_agents=$(sed -n '/^AGENTS=(/,/^)/p' scripts/install.sh | grep -c '^  "')
installer_commands=$(sed -n '/^COMMANDS=(/,/^)/p' scripts/install.sh | grep -c '^  "')

if [[ "$repo_agents" == "$installer_agents" ]]; then
  log_ok "agents: $repo_agents in .claude/agents/ == $installer_agents in install.sh"
else
  log_fail "agents: $repo_agents in .claude/agents/ but $installer_agents in install.sh — update AGENTS=() in scripts/install.sh"
fi

if [[ "$repo_commands" == "$installer_commands" ]]; then
  log_ok "commands: $repo_commands in .claude/commands/ == $installer_commands in install.sh"
else
  log_fail "commands: $repo_commands in .claude/commands/ but $installer_commands in install.sh — update COMMANDS=() in scripts/install.sh"
fi

# ─── 4. Installer end-to-end ──────────────────────────────────────────────────
log_step "Installer end-to-end (install.sh in a temp project)"

TMP_PROJECT=$(mktemp -d)
SCAN_TMP=$(mktemp -d)
HOOK_TMP=$(mktemp -d)
MAP_TMP=$(mktemp -d)
trap 'rm -rf "$TMP_PROJECT" "$SCAN_TMP" "$HOOK_TMP" "$MAP_TMP"' EXIT

(
  cd "$TMP_PROJECT" && git init -q . && bash "$ROOT/scripts/install.sh"
) > "$TMP_PROJECT/install.log" 2>&1
INSTALL_EXIT=$?

if [[ $INSTALL_EXIT -eq 0 ]]; then
  log_ok "install.sh exited 0"
else
  log_fail "install.sh exited $INSTALL_EXIT — last lines:"
  tail -5 "$TMP_PROJECT/install.log" | sed 's/^/      /'
fi

installed_agents=$(ls "$TMP_PROJECT/.claude/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')
installed_commands=$(ls "$TMP_PROJECT/.claude/commands/"*.md 2>/dev/null | wc -l | tr -d ' ')

if [[ "$installed_agents" == "$repo_agents" ]]; then
  log_ok "all $repo_agents agents installed"
else
  log_fail "installed $installed_agents agents, expected $repo_agents"
fi

if [[ "$installed_commands" == "$repo_commands" ]]; then
  log_ok "all $repo_commands commands installed"
else
  log_fail "installed $installed_commands commands, expected $repo_commands"
fi

for f in .mantaignore manta.patterns.json PATTERNS.md .claude/settings.json \
         .githooks/pre-commit .githooks/pre-push \
         scripts/shallow-scan.sh scripts/build-project-map.sh; do
  if [[ -f "$TMP_PROJECT/$f" ]]; then
    log_ok "$f installed"
  else
    log_fail "$f missing after install"
  fi
done

for h in pre-commit pre-push; do
  if [[ -x "$TMP_PROJECT/.githooks/$h" ]]; then
    log_ok ".githooks/$h is executable"
  else
    log_fail ".githooks/$h is not executable"
  fi
done

HOOKS_PATH=$(git -C "$TMP_PROJECT" config core.hooksPath || echo "")
if [[ "$HOOKS_PATH" == ".githooks" ]]; then
  log_ok "core.hooksPath configured"
else
  log_fail "core.hooksPath is '$HOOKS_PATH', expected '.githooks'"
fi

# ─── 5. Shallow-scan detection ────────────────────────────────────────────────
# Regression test for scripts/shallow-scan.sh's diff-filtering pipeline and
# pattern coverage against seeded vulnerable fixtures. This exact script once
# silently reported zero signals due to a BRE/ERE grep bug.
log_step "Shallow-scan detection (seeded fixtures)"

(
  cd "$SCAN_TMP" && git init -q . \
    && git config user.email "selftest@example.com" && git config user.name "selftest" \
    && cp -r "$ROOT/scripts/self-test-fixtures/vulnerable-app/." . \
    && git add -A
) > /dev/null 2>&1

SCAN_OUTPUT=$(cd "$SCAN_TMP" && bash "$ROOT/scripts/shallow-scan.sh" 2>&1)
SCAN_EXIT=$?

get_count() { echo "$SCAN_OUTPUT" | grep -E "^$1: " | grep -oE '[0-9]+$'; }

SECRETS_COUNT=$(get_count SECRETS)
CRYPTO_COUNT=$(get_count CRYPTO)
INJECTION_COUNT=$(get_count INJECTION)

if [[ "${SECRETS_COUNT:-0}" -ge 2 ]]; then
  log_ok "secret patterns detected (seeded AWS key + PHP define() credential)"
else
  log_fail "expected 2+ secret signals (AWS key, define() credential), got ${SECRETS_COUNT:-0} — shallow-scan.sh regression"
fi

if [[ "${CRYPTO_COUNT:-0}" -ge 1 ]]; then
  log_ok "weak crypto pattern detected (seeded md5)"
else
  log_fail "crypto pattern NOT detected — shallow-scan.sh regression"
fi

if [[ "${INJECTION_COUNT:-0}" -ge 2 ]]; then
  log_ok "injection sinks detected (seeded innerHTML + PHP string-interpolated SQL)"
else
  log_fail "expected 2+ injection signals (innerHTML, SQLi), got ${INJECTION_COUNT:-0} — shallow-scan.sh regression"
fi

if [[ $SCAN_EXIT -eq 1 ]]; then
  log_ok "shallow-scan.sh exits 1 (signals found) as expected"
else
  log_fail "shallow-scan.sh exited $SCAN_EXIT, expected 1 — last output:"
  echo "$SCAN_OUTPUT" | tail -5 | sed 's/^/      /'
fi

# ─── 6. Hook verdict parsing (fake AI shim) ───────────────────────────────────
# The hooks grep the AI's output for COMMIT_VERDICT/PUSH_VERDICT and branch on
# exit codes with a deliberate asymmetry: pre-commit WARN allows the commit
# (exit 0), pre-push WARN blocks the push (exit 1). A PATH-injected fake
# `claude` returns canned verdicts so the real hook logic runs without an API
# key. This check caught a real printf bug that killed hooks with exit 2
# before verdict parsing.
log_step "Hook verdict parsing (fake AI shim)"

mkdir -p "$HOOK_TMP/bin" "$HOOK_TMP/verdicts" "$HOOK_TMP/repo"
cat > "$HOOK_TMP/bin/claude" << 'SHIM'
#!/usr/bin/env bash
cat "$FAKE_AI_OUTPUT"
SHIM
chmod +x "$HOOK_TMP/bin/claude"

printf 'COMMIT_VERDICT: BLOCK\nBLOCK_REASON: 1 critical issue found\n' > "$HOOK_TMP/verdicts/commit-block.txt"
printf 'COMMIT_VERDICT: WARN\nBLOCK_REASON: 2 warnings found\n'        > "$HOOK_TMP/verdicts/commit-warn.txt"
printf 'COMMIT_VERDICT: PASS\n'                                        > "$HOOK_TMP/verdicts/commit-pass.txt"
printf 'PUSH_VERDICT: BLOCK\nBLOCK_REASON: 1 critical issue found\n'   > "$HOOK_TMP/verdicts/push-block.txt"
printf 'PUSH_VERDICT: WARN\nBLOCK_REASON: 2 warnings found\n'          > "$HOOK_TMP/verdicts/push-warn.txt"
printf 'PUSH_VERDICT: PASS\n'                                          > "$HOOK_TMP/verdicts/push-pass.txt"

(
  cd "$HOOK_TMP/repo" && git init -q . \
    && git config user.email "selftest@example.com" && git config user.name "selftest" \
    && echo "def base(): pass" > base.py && git add -A && git commit -qm base \
    && echo "def feature(): pass" > feature.py && git add -A && git commit -qm feature \
    && echo "def staged(): pass" > staged.py && git add staged.py
) > /dev/null 2>&1

PUSH_BASE=$(git -C "$HOOK_TMP/repo" rev-parse HEAD~1)
PUSH_HEAD=$(git -C "$HOOK_TMP/repo" rev-parse HEAD)

run_hook_commit() {  # $1 = verdict file
  ( cd "$HOOK_TMP/repo" && PATH="$HOOK_TMP/bin:$PATH" FAKE_AI_OUTPUT="$HOOK_TMP/verdicts/$1" \
      bash "$ROOT/.githooks/pre-commit" ) > /dev/null 2>&1
}
run_hook_push() {  # $1 = verdict file
  ( cd "$HOOK_TMP/repo" && PATH="$HOOK_TMP/bin:$PATH" FAKE_AI_OUTPUT="$HOOK_TMP/verdicts/$1" \
      bash "$ROOT/.githooks/pre-push" \
      <<< "refs/heads/main $PUSH_HEAD refs/heads/main $PUSH_BASE" ) > /dev/null 2>&1
}

run_hook_commit commit-block.txt; ec=$?
[[ $ec -eq 1 ]] && log_ok "pre-commit BLOCK → exit 1 (commit blocked)" \
                || log_fail "pre-commit BLOCK exited $ec, expected 1"

run_hook_commit commit-warn.txt; ec=$?
[[ $ec -eq 0 ]] && log_ok "pre-commit WARN → exit 0 (commit allowed, warned)" \
                || log_fail "pre-commit WARN exited $ec, expected 0"

run_hook_commit commit-pass.txt; ec=$?
[[ $ec -eq 0 ]] && log_ok "pre-commit PASS → exit 0" \
                || log_fail "pre-commit PASS exited $ec, expected 0"

run_hook_push push-block.txt; ec=$?
[[ $ec -eq 1 ]] && log_ok "pre-push BLOCK → exit 1 (push blocked)" \
                || log_fail "pre-push BLOCK exited $ec, expected 1"

run_hook_push push-warn.txt; ec=$?
[[ $ec -eq 1 ]] && log_ok "pre-push WARN → exit 1 (warnings block at push)" \
                || log_fail "pre-push WARN exited $ec, expected 1 — WARN must block pushes"

run_hook_push push-pass.txt; ec=$?
[[ $ec -eq 0 ]] && log_ok "pre-push PASS → exit 0" \
                || log_fail "pre-push PASS exited $ec, expected 0"

# Fail-closed regression guard: an unparseable/missing verdict must BLOCK, not
# silently pass. pre-push previously had a bug where any output lacking
# "PUSH_VERDICT: BLOCK"/"WARN" fell through to the PASS branch — including
# garbage with no verdict at all.
printf 'garbage output, no verdict line at all\n' > "$HOOK_TMP/verdicts/garbage.txt"

run_hook_commit garbage.txt; ec=$?
[[ $ec -eq 1 ]] && log_ok "pre-commit unparseable verdict → exit 1 (fail-closed)" \
                || log_fail "pre-commit unparseable verdict exited $ec, expected 1 (fail-closed regression)"

run_hook_push garbage.txt; ec=$?
[[ $ec -eq 1 ]] && log_ok "pre-push unparseable verdict → exit 1 (fail-closed)" \
                || log_fail "pre-push unparseable verdict exited $ec, expected 1 — previously fell through to PASS"

( cd "$HOOK_TMP/repo" && SKIP_CLAUDE_REVIEW=1 bash "$ROOT/.githooks/pre-commit" ) > /dev/null 2>&1; ec=$?
[[ $ec -eq 0 ]] && log_ok "SKIP_CLAUDE_REVIEW=1 bypasses pre-commit (exit 0)" \
                || log_fail "SKIP_CLAUDE_REVIEW=1 exited $ec, expected 0"

( cd "$HOOK_TMP/repo" && SKIP_CLAUDE_PUSH_REVIEW=1 bash "$ROOT/.githooks/pre-push" \
    <<< "refs/heads/main $PUSH_HEAD refs/heads/main $PUSH_BASE" ) > /dev/null 2>&1; ec=$?
[[ $ec -eq 0 ]] && log_ok "SKIP_CLAUDE_PUSH_REVIEW=1 bypasses pre-push (exit 0)" \
                || log_fail "SKIP_CLAUDE_PUSH_REVIEW=1 exited $ec, expected 0"

# ─── 7. Project-map classification and cache invalidation ─────────────────────
log_step "Project-map classification (seeded fixture)"

(
  cd "$MAP_TMP" && git init -q . \
    && git config user.email "selftest@example.com" && git config user.name "selftest" \
    && mkdir -p src/auth src/payments migrations tests \
    && echo "def login(): pass" > src/auth/login.py \
    && echo "def charge(): pass" > src/payments/stripe_billing.py \
    && echo "ALTER TABLE users ADD COLUMN x;" > migrations/001_init.sql \
    && echo "def test_login(): pass" > tests/test_login.py \
    && git add -A && git commit -qm fixture
) > /dev/null 2>&1

MAP_JSON=$(cd "$MAP_TMP" && bash "$ROOT/scripts/build-project-map.sh" 2>/dev/null)

MAP_CHECK=$(echo "$MAP_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
ok = lambda lst, frag: any(frag in f for f in d.get(lst, []))
failures = []
if not ok('auth_files', 'src/auth/login.py'):            failures.append('auth_files missed src/auth/login.py')
if not ok('payment_files', 'stripe_billing.py'):          failures.append('payment_files missed stripe_billing.py')
if not ok('migration_files', 'migrations/001_init.sql'):  failures.append('migration_files missed migrations/001_init.sql')
if not ok('test_files', 'tests/test_login.py'):           failures.append('test_files missed tests/test_login.py')
print('; '.join(failures) if failures else 'OK')
" 2>&1)

if [[ "$MAP_CHECK" == "OK" ]]; then
  log_ok "auth/payment/migration/test files classified correctly"
else
  log_fail "classification regression: $MAP_CHECK"
fi

SECOND_RUN=$(cd "$MAP_TMP" && bash "$ROOT/scripts/build-project-map.sh" 2>&1 >/dev/null)
if echo "$SECOND_RUN" | grep -q "cache hit"; then
  log_ok "unchanged tree → cache hit"
else
  log_fail "expected cache hit on unchanged tree, got: $(echo "$SECOND_RUN" | head -1)"
fi

( cd "$MAP_TMP" && echo "def token(): pass" > src/auth/token.py && git add src/auth/token.py ) > /dev/null 2>&1
THIRD_RUN=$(cd "$MAP_TMP" && bash "$ROOT/scripts/build-project-map.sh" 2>&1 >/dev/null)
if echo "$THIRD_RUN" | grep -q "Building"; then
  log_ok "staged file invalidates cache (content-keyed, not HEAD-keyed)"
else
  log_fail "staged file did NOT invalidate cache — HEAD-only key regression: $(echo "$THIRD_RUN" | head -1)"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════${RESET}"
if [[ $FAILURES -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}✅ Self-test passed${RESET}"
  exit 0
else
  echo -e "${RED}${BOLD}✗ Self-test failed: $FAILURES issue(s)${RESET}"
  exit 1
fi
