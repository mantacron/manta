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

# macOS still ships bash 3.2, and the hooks, the installer and the scanners run
# under whatever `bash` a developer has. Associative arrays, namerefs, mapfile,
# case-folding and the other bash-4 forms fail there — usually as an "invalid
# option" that stops a `set -e` script. build-project-map.sh carried two unused
# `declare -A` maps, so on a Mac the project map never built.
log_step "Shipped shell runs on macOS bash 3.2"
B4_RE='declare -[Agn]|local -[An]|(^|[^a-z_])(mapfile|readarray|coproc)[[:space:]]|\$\{[A-Za-z_][A-Za-z0-9_]*(,,?|\^\^?)\}|\$\{[A-Za-z_][A-Za-z0-9_]*@[QEPAaUuLK]\}|\$\{[A-Za-z_][A-Za-z0-9_]*\[-[0-9]+\]\}|&>>|\|&|\[\[ -v '
B4_FILES=()
for f in .githooks/* scripts/*.sh; do
  [[ "$f" == scripts/self-test.sh ]] || B4_FILES+=("$f")   # not shipped, and quotes the pattern
done
B4_HITS=$(grep -nE "$B4_RE" "${B4_FILES[@]}" 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)
if [[ -z "$B4_HITS" ]]; then
  log_ok "no bash-4-only syntax in ${#B4_FILES[@]} shipped shell scripts"
else
  log_fail "bash-4-only syntax in a shipped script — breaks on macOS bash 3.2:"
  echo "$B4_HITS" | head -5 | sed 's/^/      /'
fi

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

# ─── 4b. Updating an install ──────────────────────────────────────────────────
# `--force` was the only documented update, and it replaced the developer's
# patterns, suppressions, settings and CLAUDE.md with templates. --update
# refreshes Manta's files and keeps theirs — twice in a row, byte for byte.
log_step "Installer --update keeps the developer's files"

UPD_TMP=$(mktemp -d "$HOOK_TMP/update.XXXXXX")
(
  cd "$UPD_TMP" && git init -q . \
    && printf '# Our project\nWe keep suppressions in .mantaignore.\n' > CLAUDE.md \
    && printf '# Our own agent instructions\n' > AGENTS.md \
    && bash "$ROOT/scripts/install.sh" \
    && printf 'src/legacy/**  DRY  # generated\n' >> .mantaignore \
    && printf '# Team patterns\n' > PATTERNS.md \
    && printf '{"naming": {"source_files": "kebab-case"}}\n' > manta.patterns.json \
    && echo "tampered" >> .claude/agents/code-quality.md \
    && python3 -c 'import json;p=".claude/settings.json";d=json.load(open(p));d["permissions"]["allow"].append("Bash(our-tool*)");json.dump(d,open(p,"w"),indent=2)' \
    && for f in .mantaignore PATTERNS.md manta.patterns.json CLAUDE.md AGENTS.md; do cp "$f" "$f.mine"; done \
    && bash "$ROOT/scripts/install.sh" --update && bash "$ROOT/scripts/install.sh" --update
) > "$UPD_TMP.log" 2>&1
UPD_EXIT=$?
UPD_BAD=""
[[ $UPD_EXIT -eq 0 ]] || UPD_BAD="$UPD_BAD [install/update exited $UPD_EXIT]"
for f in .mantaignore PATTERNS.md manta.patterns.json CLAUDE.md AGENTS.md; do
  cmp -s "$UPD_TMP/$f" "$UPD_TMP/$f.mine" || UPD_BAD="$UPD_BAD [$f changed]"
done
cmp -s "$UPD_TMP/.claude/agents/code-quality.md" "$ROOT/.claude/agents/code-quality.md" \
  || UPD_BAD="$UPD_BAD [a Manta agent was not refreshed]"
cmp -s "$UPD_TMP/.claude/settings.json" "$ROOT/.claude/settings.json" \
  || UPD_BAD="$UPD_BAD [settings.json was not refreshed]"
grep -q 'our-tool' "$UPD_TMP/.claude/settings.json.pre-update" 2>/dev/null \
  || UPD_BAD="$UPD_BAD [the developer's settings were not kept in .pre-update]"
git -C "$UPD_TMP" check-ignore -q .claude/settings.json.pre-update \
  || UPD_BAD="$UPD_BAD [settings.json.pre-update is not git-ignored]"
# The appended reference block: present although CLAUDE.md said ".mantaignore"
# (any lowercase "manta" used to count as present), and present once.
blocks=$(grep -c '^## Manta — AI Review Pipeline$' "$UPD_TMP/CLAUDE.md" 2>/dev/null || true)
[[ "$blocks" == "1" ]] || UPD_BAD="$UPD_BAD [CLAUDE.md carries the reference block ${blocks:-0} times]"
[[ -z "$UPD_BAD" ]] \
  && log_ok "--update twice: patterns, suppressions, CLAUDE.md and an own AGENTS.md kept; Manta's files and settings refreshed" \
  || { log_fail "install.sh --update:$UPD_BAD"; tail -5 "$UPD_TMP.log" | sed 's/^/      /'; }

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

# ─── 5b. Routing signals: new routes and new symbols ─────────────────────────
# Enterprise routes test-architect and observability-guardian on these flags;
# here they are printed and persisted, and must say the same about a diff.
log_step "Shallow-scan routing signals"

scan_fixture() {  # $1 = setup commands run inside a fresh repo → prints scanner output
  local repo
  repo=$(mktemp -d "$HOOK_TMP/rf.XXXXXX")
  ( cd "$repo" && git init -q . && git config user.email t@t && git config user.name t && eval "$1" ) > /dev/null 2>&1
  ( cd "$repo" && bash "$ROOT/scripts/shallow-scan.sh" 2>/dev/null || true )
}
RF_BAD=""
# A large diff with a route near the top. `echo "$ADDED_LINES" | grep -q` let
# grep exit on its first match while echo was still writing; echo died of
# SIGPIPE, pipefail made the match 141, and both flags read false. (The filler
# comes from awk, not `yes | head` — under pipefail that is the same bug.)
out=$(scan_fixture 'mkdir -p src && printf "def handler():\n    pass\nrouter.get(\"/x\", handler)\n" > src/a_api.py \
  && awk "BEGIN { for (i = 0; i < 100000; i++) print \"filler = 1\" }" > src/z_big.py && git add -A')
grep -q '^HAS_API_ROUTES: true' <<< "$out" && grep -q '^HAS_NEW_SYMBOLS: true' <<< "$out" \
  || RF_BAD="$RF_BAD [a large diff lost its route/symbol flags]"
# A route whose handler is an inline arrow declares no named symbol.
out=$(scan_fixture "mkdir -p src && printf \"router.patch('/:id/status', (req, res) => res.json({}));\n\" > src/routes.js && git add -A")
grep -q '^HAS_NEW_SYMBOLS: true' <<< "$out" || RF_BAD="$RF_BAD [an inline-handler route is not new behaviour]"
# A Next.js App Router handler is an exported method name, with no router call.
out=$(scan_fixture 'mkdir -p app/api/x && printf "export const GET = async () => Response.json({});\n" > app/api/x/route.ts && git add -A')
grep -q '^HAS_API_ROUTES: true' <<< "$out" || RF_BAD="$RF_BAD [a Next.js route.ts handler is not a route]"
# A new method on an existing class. The class is committed first, so the only
# added symbol is the indented def — a fixture whose added lines include
# `class` passes the old column-0 pattern and proves nothing.
out=$(scan_fixture 'printf "class Billing:\n    pass\n" > billing.py && git add -A && git commit -qm base \
  && printf "    def refund(self, amount):\n        return amount\n" >> billing.py && git add -A')
grep -q '^HAS_NEW_SYMBOLS: true' <<< "$out" || RF_BAD="$RF_BAD [an indented def is not a new symbol]"
# An access-modified method with a generic return type: written with backslash
# escapes, the type-name bracket expression closed early and never matched.
out=$(scan_fixture 'printf "class Svc {\n" > Svc.cs && git add -A && git commit -qm base \
  && printf "    public async Task<int> Run(int a) {\n    }\n" >> Svc.cs && git add -A')
grep -q '^HAS_NEW_SYMBOLS: true' <<< "$out" || RF_BAD="$RF_BAD [a new C# method is not a new symbol]"
for decl in 'func Charge(amount int) error {' 'pub async fn charge(amount: u64) {' 'export const charge = async (amount) => {'; do
  out=$(scan_fixture "printf '%s\n' '$decl' > src.txt && git add -A")
  grep -q '^HAS_NEW_SYMBOLS: true' <<< "$out" || RF_BAD="$RF_BAD [not a new symbol: $decl]"
done
# And the negative: prose is not a symbol.
out=$(scan_fixture 'printf "# Notes\nsome words\n" > NOTES.md && git add -A')
grep -q '^HAS_NEW_SYMBOLS: false' <<< "$out" || RF_BAD="$RF_BAD [a docs-only diff reads as new symbols]"
[[ -z "$RF_BAD" ]] \
  && log_ok "routes (inline, Next.js, large diffs) and new symbols (methods, C#/Java, Go, Rust, arrows) are detected" \
  || log_fail "routing signals wrong:$RF_BAD"

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

# Verdict-hijack regression guard: the verdict greps were unanchored, so a
# finding that merely *quoted* the contract string decided the verdict. Reviewing
# any repo that contains a review pipeline hit this — a clean PASS read as BLOCK.
{
  printf '=== CLAUDE PRE-COMMIT REVIEW ===\n'
  printf 'CRITICAL ISSUES:\nNone\n'
  printf 'WARNINGS:\n1. [code-quality] hooks.md:12 — docs quote COMMIT_VERDICT: BLOCK and COMMIT_VERDICT: WARN\n'
  printf '=== END REVIEW ===\n'
  printf 'COMMIT_VERDICT: PASS\n'
} > "$HOOK_TMP/verdicts/commit-pass-quoting-verdicts.txt"

run_hook_commit commit-pass-quoting-verdicts.txt; ec=$?
[[ $ec -eq 0 ]] && log_ok "quoted verdict strings in findings do not hijack the verdict (PASS stays PASS)" \
                || log_fail "pre-commit exited $ec on a PASS whose findings quote BLOCK/WARN — unanchored verdict grep regression"

rm -f "$HOOK_TMP/repo/reports/.bypass-log"
( cd "$HOOK_TMP/repo" && SKIP_CLAUDE_REVIEW=1 bash "$ROOT/.githooks/pre-commit" ) > /dev/null 2>&1; ec=$?
# The commit bypass used to exit silently while the push bypass was logged. That
# asymmetry made the audit trail unusable as evidence, so assert it is recorded.
if [[ $ec -eq 0 ]] && grep -q "pre-commit review bypassed" "$HOOK_TMP/repo/reports/.bypass-log" 2>/dev/null; then
  log_ok "SKIP_CLAUDE_REVIEW=1 bypasses pre-commit (exit 0) and logs the bypass"
else
  log_fail "pre-commit bypass: exit $ec (expected 0), bypass-log entry $(grep -qs 'pre-commit review bypassed' "$HOOK_TMP/repo/reports/.bypass-log" && echo present || echo MISSING)"
fi

( cd "$HOOK_TMP/repo" && SKIP_CLAUDE_PUSH_REVIEW=1 bash "$ROOT/.githooks/pre-push" \
    <<< "refs/heads/main $PUSH_HEAD refs/heads/main $PUSH_BASE" ) > /dev/null 2>&1; ec=$?
[[ $ec -eq 0 ]] && log_ok "SKIP_CLAUDE_PUSH_REVIEW=1 bypasses pre-push (exit 0)" \
                || log_fail "SKIP_CLAUDE_PUSH_REVIEW=1 exited $ec, expected 0"

# The push bypass line used to record "unknown → unknown" because stdin was read
# after the skip check — losing the commit range on the one record where it matters.
if grep -q "pre-push review bypassed" "$HOOK_TMP/repo/reports/.bypass-log" 2>/dev/null \
   && ! grep "pre-push review bypassed" "$HOOK_TMP/repo/reports/.bypass-log" | grep -q "commits: unknown → unknown"; then
  log_ok "pre-push bypass records the real commit range, not unknown → unknown"
else
  log_fail "pre-push bypass line lost its SHAs — stdin must be read before the skip check"
fi

# ─── 6b. What the reviewer may do, and the block both hooks share ────────────
# Claude Code ignores the allow list in .claude/settings.json until someone has
# accepted the trust dialog in the folder, which a headless hook run never
# shows, so the reviewer's grant has to arrive as --allowedTools. The deny list
# is what stops a diff from asking the reviewer to run its own test script.
# A shim records exactly what the hook handed the CLI.
log_step "Reviewer permissions reach the AI CLI"

mkdir -p "$HOOK_TMP/argbin"
cat > "$HOOK_TMP/argbin/claude" << 'SHIM'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$FAKE_AI_ARGS"
printf 'BACKGROUND_TASKS_OFF=%s\n' "${CLAUDE_CODE_DISABLE_BACKGROUND_TASKS:-}" >> "$FAKE_AI_ARGS"
printf 'COMMIT_VERDICT: PASS\nPUSH_VERDICT: PASS\n'
SHIM
chmod +x "$HOOK_TMP/argbin/claude"

perm_problems() {  # $1 = file of recorded args → prints what is missing
  local f="$1" allow deny
  allow=$(grep -A1 -x -- '--allowedTools' "$f" 2>/dev/null | tail -1)
  deny=$(grep -A1 -x -- '--disallowedTools' "$f" 2>/dev/null | tail -1)
  [[ "$allow" == *'Bash(git diff*)'* && "$allow" == *'Read'* && "$allow" == *'Bash(bash scripts/shallow-scan.sh*)'* ]] \
    || echo "no read-only --allowedTools grant"
  local rule
  for rule in 'WebFetch' 'Bash(curl*)' 'Bash(npm test*)' 'Bash(npm run*)' 'Bash(pytest*)' 'Bash(make*)' \
              'Bash(git commit*)' 'Bash(git stash*)' 'Bash(git * --output*)' 'Bash(npm audit fix*)' \
              'Bash(find * -exec*)' 'Write' 'Edit'; do
    [[ ",$deny," == *",$rule,"* ]] || echo "deny list lacks $rule"
  done
  grep -qx 'BACKGROUND_TASKS_OFF=1' "$f" 2>/dev/null \
    || echo "CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 did not reach the CLI"
}

( cd "$HOOK_TMP/repo" && PATH="$HOOK_TMP/argbin:$PATH" FAKE_AI_ARGS="$HOOK_TMP/commit-args" \
    bash "$ROOT/.githooks/pre-commit" ) > /dev/null 2>&1
( cd "$HOOK_TMP/repo" && PATH="$HOOK_TMP/argbin:$PATH" FAKE_AI_ARGS="$HOOK_TMP/push-args" \
    bash "$ROOT/.githooks/pre-push" <<< "refs/heads/main $PUSH_HEAD refs/heads/main $PUSH_BASE" ) > /dev/null 2>&1
PERM_BAD=""
for kind in commit push; do
  [[ -s "$HOOK_TMP/$kind-args" ]] || { PERM_BAD="$PERM_BAD [$kind: the CLI was never called]"; continue; }
  while IFS= read -r p; do PERM_BAD="$PERM_BAD [$kind: $p]"; done < <(perm_problems "$HOOK_TMP/$kind-args")
done
[[ -z "$PERM_BAD" ]] \
  && log_ok "both hooks pass the read-only grant, the deny list and foreground agents to claude" \
  || log_fail "reviewer permissions:$PERM_BAD"

# The two hooks carry one shared block; a fix landing in only one is a gate
# that is wrong in one direction with nothing else failing.
shared_block() { sed -n '/^# ═══ Shared hook block/,/^# ═══ End of shared hook block/p' "$1"; }
if [[ -n "$(shared_block "$ROOT/.githooks/pre-commit")" ]] \
   && diff <(shared_block "$ROOT/.githooks/pre-commit") <(shared_block "$ROOT/.githooks/pre-push") > /dev/null; then
  log_ok "pre-commit and pre-push carry the same shared block"
else
  log_fail "the shared block differs between pre-commit and pre-push (or is missing) — copy the fix to both"
fi

# ─── 6c. What the gates review ────────────────────────────────────────────────
# One definition of "code" for both gates. The push hook once lacked .sh, so a
# branch changing only shell scripts went out unreviewed; neither had .sql, so a
# migration-only commit skipped db-migration-guardian; the gate's own config
# (.mantaignore, settings, agent files) was "non-code" and went through unseen.
log_step "What the gates review"

mkdir -p "$HOOK_TMP/callbin"
cat > "$HOOK_TMP/callbin/claude" << 'SHIM'
#!/usr/bin/env bash
: > "$FAKE_AI_CALLED"
printf 'COMMIT_VERDICT: PASS\nPUSH_VERDICT: PASS\n'
SHIM
chmod +x "$HOOK_TMP/callbin/claude"

commit_reviews() {  # $1 = path to stage (content written for it) → "reviewed" | "skipped"
  # A fresh repository per path. Called inside $( ), so a counter would not
  # survive the subshell — every case would land in the first repository.
  local repo
  repo=$(mktemp -d "$HOOK_TMP/filter.XXXXXX")
  mkdir -p "$repo/$(dirname "$1")"
  (
    cd "$repo" && git init -q . \
      && git config user.email t@t && git config user.name t \
      && printf '#!/usr/bin/env bash\necho hi\n' > "$1" && chmod +x "$1" \
      && git add -A
  ) > /dev/null 2>&1
  rm -f "$HOOK_TMP/called"
  ( cd "$repo" && PATH="$HOOK_TMP/callbin:$PATH" FAKE_AI_CALLED="$HOOK_TMP/called" \
      bash "$ROOT/.githooks/pre-commit" ) > /dev/null 2>&1
  [[ -f "$HOOK_TMP/called" ]] && echo reviewed || echo skipped
}

FILTER_BAD=""
for p in .mantaignore .claude/settings.json manta.patterns.json .claude/agents/x.md \
         migrations/001_init.sql templates/page.html infra/main.tf Dockerfile package.json \
         .githooks/custom-gate scripts/deploy.sh; do
  [[ "$(commit_reviews "$p")" == reviewed ]] || FILTER_BAD="$FILTER_BAD [$p skipped]"
done
for p in README.md docker-compose.yml package-lock.json notes/plan.txt; do
  [[ "$(commit_reviews "$p")" == skipped ]] || FILTER_BAD="$FILTER_BAD [$p reviewed]"
done
[[ -z "$FILTER_BAD" ]] \
  && log_ok "gate config, migrations, templates, IaC, Dockerfiles, manifests and hooks are reviewed; docs, compose and lockfiles are not" \
  || log_fail "the commit gate's idea of code is wrong:$FILTER_BAD"

# A push of nothing but a shell script: the push hook's list once lacked .sh.
(
  cd "$HOOK_TMP/repo" && git reset -q && git checkout -q -b sh-only \
    && printf '#!/usr/bin/env bash\necho deploy\n' > deploy.sh && git add deploy.sh && git commit -qm sh
) > /dev/null 2>&1
SH_HEAD=$(git -C "$HOOK_TMP/repo" rev-parse HEAD)
rm -f "$HOOK_TMP/called"
( cd "$HOOK_TMP/repo" && PATH="$HOOK_TMP/callbin:$PATH" FAKE_AI_CALLED="$HOOK_TMP/called" \
    bash "$ROOT/.githooks/pre-push" <<< "refs/heads/sh-only $SH_HEAD refs/heads/sh-only $PUSH_HEAD" ) > /dev/null 2>&1
[[ -f "$HOOK_TMP/called" ]] \
  && log_ok "a push that changes only a shell script is reviewed" \
  || log_fail "a push of only a .sh file skipped review — the push hook's code list lacks .sh"

# A diff git cannot produce is not an empty diff. An unfetched remote commit made
# `git diff` fail, the pipeline's `|| true` turned that into "no code changed",
# and the push went out unreviewed.
rm -f "$HOOK_TMP/called"
( cd "$HOOK_TMP/repo" && PATH="$HOOK_TMP/callbin:$PATH" FAKE_AI_CALLED="$HOOK_TMP/called" \
    bash "$ROOT/.githooks/pre-push" <<< "refs/heads/sh-only $SH_HEAD refs/heads/sh-only 1234567890abcdef1234567890abcdef12345678" ) > /dev/null 2>&1; ec=$?
[[ $ec -eq 1 && ! -f "$HOOK_TMP/called" ]] \
  && log_ok "an unreadable branch diff blocks the push (fail-closed)" \
  || log_fail "an unreadable branch diff exited $ec — it must block, not pass as 'no code'"

# `git push origin :old-branch sh-only` sends the deletion first. Reading only
# the first line let the real branch through behind it, unreviewed.
rm -f "$HOOK_TMP/called"
( cd "$HOOK_TMP/repo" && PATH="$HOOK_TMP/callbin:$PATH" FAKE_AI_CALLED="$HOOK_TMP/called" \
    bash "$ROOT/.githooks/pre-push" <<< "(delete) 0000000000000000000000000000000000000000 refs/heads/old $PUSH_BASE
refs/heads/sh-only $SH_HEAD refs/heads/sh-only $PUSH_HEAD" ) > /dev/null 2>&1; ec=$?
[[ $ec -eq 0 && -f "$HOOK_TMP/called" ]] \
  && log_ok "a branch deletion pushed beside a real branch does not carry it past review" \
  || log_fail "a deletion line first let the pushed branch through unreviewed (exit $ec)"

# The install commit carries only Manta's own files; reviewing them is reviewing
# Manta, at the developer's expense. They are skipped while byte-identical to
# what install.sh wrote on this machine — and an edited one is reviewed again.
# Uses the project section 4 installed into.
( cd "$TMP_PROJECT" && git add -A ) > /dev/null 2>&1
rm -f "$HOOK_TMP/called"
SKIP_OUT=$( cd "$TMP_PROJECT" && PATH="$HOOK_TMP/callbin:$PATH" FAKE_AI_CALLED="$HOOK_TMP/called" \
    bash .githooks/pre-commit 2>&1 )
if [[ ! -f "$HOOK_TMP/called" ]] && grep -q "Manta file(s) exactly as installed" <<< "$SKIP_OUT"; then
  log_ok "the install commit's Manta files are skipped while unchanged"
else
  log_fail "the install commit was reviewed — installed-blobs.tsv missing or not honoured"
fi
( cd "$TMP_PROJECT" && echo "# edited after install" >> scripts/models.sh && git add scripts/models.sh ) > /dev/null 2>&1
rm -f "$HOOK_TMP/called"
( cd "$TMP_PROJECT" && PATH="$HOOK_TMP/callbin:$PATH" FAKE_AI_CALLED="$HOOK_TMP/called" \
    bash .githooks/pre-commit ) > /dev/null 2>&1
[[ -f "$HOOK_TMP/called" ]] \
  && log_ok "an installed file edited afterwards is reviewed" \
  || log_fail "an edited Manta file was skipped — the skip list must match the exact blob"
# A committed list could mark a teammate's own edit "installed" on every machine
# that pulls it. Undo the edit (the list vouches for every file again), commit
# the list by force, and the hook must ignore it and review.
( cd "$TMP_PROJECT" \
    && git cat-file -p "$(awk -F'\t' '$2 == "scripts/models.sh" { print $1; exit }' .manta-cache/installed-blobs.tsv)" > scripts/models.sh \
    && git add scripts/models.sh && git add -f .manta-cache/installed-blobs.tsv ) > /dev/null 2>&1
rm -f "$HOOK_TMP/called"
TRACKED_OUT=$( cd "$TMP_PROJECT" && PATH="$HOOK_TMP/callbin:$PATH" FAKE_AI_CALLED="$HOOK_TMP/called" \
    bash .githooks/pre-commit 2>&1 )
if [[ -f "$HOOK_TMP/called" ]] && grep -q "committed to the repository" <<< "$TRACKED_OUT"; then
  log_ok "a committed installed-blobs.tsv is ignored — everything is reviewed"
else
  log_fail "a committed installed-blobs.tsv was trusted — a teammate could mark their own edit as installed"
fi
( cd "$TMP_PROJECT" && git rm -q --cached .manta-cache/installed-blobs.tsv ) > /dev/null 2>&1

# ─── 6d. The Claude Code hooks in .claude/settings.json ──────────────────────
# The guard against an assistant skipping the gate with `--no-verify` read
# $CLAUDE_TOOL_INPUT, which Claude Code never sets — tool input arrives as JSON
# on stdin — so it never fired. Run it the way Claude Code does, on both kinds
# of case: a bypass must be refused, and `-n` that is not git commit's own flag
# (inside a message, in a later command) must not be.
log_step "Claude Code hooks (settings.json)"

settings_hook() {  # $1 = PreToolUse | PostToolUse
  python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['hooks'][sys.argv[2]][0]['hooks'][0]['command'])" \
    "$ROOT/.claude/settings.json" "$1" 2>/dev/null
}
# The tool input Claude Code sends, as a file to redirect from: a pipe would let
# a hook that never reads stdin fail its writer under pipefail instead of itself.
tool_input() {  # $1 = the Bash command → prints the path of the JSON file
  python3 -c 'import json,sys;print(json.dumps({"tool_input":{"command":sys.argv[1]}}))' "$1" \
    > "$HOOK_TMP/tool-input.json"
  echo "$HOOK_TMP/tool-input.json"
}

GUARD_CMD=$(settings_hook PreToolUse)
GUARD_BAD=""
guard_case() {  # $1 = expected exit (2 blocks, 0 allows), $2 = the Bash command
  local got=0 input
  input=$(tool_input "$2")
  bash -c "$GUARD_CMD" < "$input" > /dev/null 2>&1 || got=$?
  [[ "$got" == "$1" ]] || GUARD_BAD="$GUARD_BAD [$2 → $got]"
}
if [[ -n "$GUARD_CMD" ]]; then
  guard_case 2 'git commit --no-verify -m x'
  guard_case 2 'git commit -anm x'
  guard_case 2 'cd repo && git commit -n'
  guard_case 2 'git commit -m "msg" --no-verify'
  guard_case 2 "git commit -m 'msg' -n"
  guard_case 2 'git commit -m "a; b && c" --no-verify'
  guard_case 0 'git commit -m "msg with --no-verify inside"'
  guard_case 0 'git commit -m "add -n flag"'
  guard_case 0 'git commit -F msg.txt && ls -n'
  guard_case 0 'git commit -F msg.txt | tail -n 5'
  [[ -z "$GUARD_BAD" ]] \
    && log_ok "the --no-verify guard blocks every bypass form and nothing else" \
    || log_fail "the --no-verify guard misjudged:$GUARD_BAD"
  # The way out it names must be the variable the hook reads.
  skip_named=$(grep -oE 'SKIP_[A-Z_]+=1' <<< "$GUARD_CMD" | head -1)
  grep -q "SKIP_VAR=\"${skip_named%=1}\"" "$ROOT/.githooks/pre-commit" \
    && log_ok "the guard's bypass advice names the variable pre-commit reads ($skip_named)" \
    || log_fail "the guard tells people to use ${skip_named:-nothing}, which pre-commit does not read"
else
  log_fail "no PreToolUse guard in .claude/settings.json — an assistant can commit with --no-verify"
fi

NOTICE_CMD=$(settings_hook PostToolUse)
notice_for() { local input; input=$(tool_input "$1"); bash -c "$NOTICE_CMD" < "$input" 2>/dev/null; }
if [[ -n "$NOTICE_CMD" ]] \
   && notice_for 'npm install left-pad' | grep -q 'Dependency change detected' \
   && ! notice_for 'ls -la' | grep -q 'Dependency change detected'; then
  log_ok "the dependency notice fires on an install and stays quiet otherwise"
else
  log_fail "the PostToolUse dependency notice does not read the tool input Claude Code sends"
fi

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

log_step "Model policy and review scope"

# These mirror the enterprise guards. When this tree is published as a
# standalone repository the enterprise self-test no longer watches it, so the
# regressions it guards against — an agent pinned back to a fixed model, the
# repo-audit-per-commit scope leak, the reporter's stranded verdict block —
# must fail CI here too.
# A read loop, not mapfile: a contributor on macOS runs this under bash 3.2.
_HOOK_AGENTS=()
while IFS= read -r _a; do _HOOK_AGENTS+=("$_a"); done < <(sed -n '/^HOOK_AGENTS=(/,/^)/p' "$ROOT/scripts/models.sh" \
  | sed '1d;$d' | sed 's/#.*//' | tr ' ' '\n' | sed '/^$/d')
if [[ ${#_HOOK_AGENTS[@]} -lt 3 ]]; then
  log_fail "could not parse HOOK_AGENTS from scripts/models.sh — the model guard is checking nothing"
fi
_POLICY_OK=1
for agent in ${_HOOK_AGENTS[@]+"${_HOOK_AGENTS[@]}"}; do
  f="$ROOT/.claude/agents/$agent.md"
  [[ -f "$f" ]] || continue   # community ships a subset of the enterprise roster
  m=$(grep -m1 '^model:' "$f" | sed 's/^model:[[:space:]]*//' | tr -d '[:space:]')
  [[ "$m" == "inherit" ]] \
    || { log_fail "$agent declares 'model: ${m:-<unset>}' — hook-path agents must be 'inherit' so MANTA_MODEL works"; _POLICY_OK=0; }
done
grep -rql 'Always read the complete file' "$ROOT/.claude/agents" 2>/dev/null \
  && { log_fail "an agent says 'Always read the complete file' again — contradicts the commit-mode budget"; _POLICY_OK=0; }
for agent in security-sentinel code-quality perf-analyzer db-migration-guardian; do
  f="$ROOT/.claude/agents/$agent.md"
  [[ -f "$f" ]] && { grep -q '^## Review Scope' "$f" \
    || { log_fail "$agent has no Review Scope section"; _POLICY_OK=0; }; }
done
grep -q '^## The return contract' "$ROOT/.claude/agents/review-reporter.md" \
  || { log_fail "review-reporter lost its return-contract section — the verdict block can strand again"; _POLICY_OK=0; }
grep -qE '^\- \*\*perf-analyzer\*\*' "$ROOT/.claude/commands/pre-commit-review.md" \
  && { log_fail "perf-analyzer is back in the commit roster — it belongs at push"; _POLICY_OK=0; }
# The roster the reporter PRINTS is a second copy of that fact, and it drifted
# from it unseen: the commit template kept a perf-analyzer line after the agent
# moved to push, so the reporter filled it in and the output claimed an agent
# had run that nothing had dispatched. The commit-mode template is the first
# AGENT RESULTS block; the second is push mode, where perf-analyzer belongs.
_commit_block=$(awk '/^AGENT RESULTS:/{n++} n==1{print} /^$/{if (n==1) exit}' \
  "$ROOT/.claude/agents/review-reporter.md")
grep -q 'perf-analyzer' <<< "$_commit_block" \
  && { log_fail "review-reporter's commit template names perf-analyzer — it will invent a status for an agent that never ran"; _POLICY_OK=0; }
grep -q 'Never write a status for' "$ROOT/.claude/agents/review-reporter.md" \
  || { log_fail "review-reporter lost the rule forbidding statuses for agents that never ran"; _POLICY_OK=0; }
# What the reporter must surface and what it must never count. A defect two
# agents rated INFO was lost because commit output printed no INFO at all; a
# spec-delegated control blocked a push when two agents agreed on it; and a
# manta-ignore comment that existed only on disk excused staged code.
_RR="$ROOT/.claude/agents/review-reporter.md"
for kind in COMMIT PUSH; do
  awk -v v="${kind}_VERDICT: PASS" '/^```$/{blk=""; next} {blk=blk $0 "\n"} index($0, v) == 1 {print blk; exit}' "$_RR" \
    | grep -q '^INFO:$' \
    || { log_fail "review-reporter's $kind template has no INFO section — an INFO-rated defect is never shown"; _POLICY_OK=0; }
done
grep -q '\[spec: delegated\]' "$_RR" \
  || { log_fail "review-reporter does not handle [spec: delegated] — a delegated control can block a push"; _POLICY_OK=0; }
grep -q 'raised from INFO: two reviewers found the same defect' "$_RR" \
  || { log_fail "review-reporter lost the agreement floor — a defect two agents rated INFO stays invisible"; _POLICY_OK=0; }
grep -q 'git show ":<file>"' "$_RR" \
  || { log_fail "review-reporter reads inline suppressions from disk in commit mode — an unstaged comment can excuse staged code"; _POLICY_OK=0; }
[[ $_POLICY_OK -eq 1 ]] && log_ok "model policy, review scope, the 3-agent roster and the reporter's rules all hold"

# ─── The hook can read the verdict the reporter actually writes ──────────────
#
# The reporter is a model writing to a format, and on a real push it wrote
# `**PUSH_VERDICT: PASS**`. The parser was anchored straight at the keyword, so
# a passing review became "no parseable PUSH_VERDICT — push BLOCKED". Fail-closed
# is the right direction and it was still a blocked push with a clean review
# behind it, which is the shape of failure that teaches people to set
# SKIP_CLAUDE_PUSH_REVIEW=1.
#
# The regex is read out of the hook rather than restated here: a copy would let
# the two drift, and this test would then pass on a pattern nothing uses.
log_step "Verdict parsing survives the markdown the reporter emits"

VERDICT_OK=1
for hook_kind in "pre-push:PUSH" "pre-commit:COMMIT"; do
  hook="${hook_kind%%:*}"; kind="${hook_kind##*:}"
  hook_file="$ROOT/.githooks/$hook"
  [[ -f "$hook_file" ]] || { log_fail "missing $hook_file"; VERDICT_OK=0; continue; }

  prefix=$(sed -n "s/^MANTA_VERDICT_PREFIX='\(.*\)'$/\1/p" "$hook_file" | head -1)
  if [[ -z "$prefix" ]]; then
    log_fail "$hook: MANTA_VERDICT_PREFIX is gone — the parser is anchored at the keyword again"
    VERDICT_OK=0
    continue
  fi

  # Must be read: the emphasis a reporter reaches for unprompted.
  while IFS= read -r line; do
    grep -qE "${prefix}${kind}_VERDICT:[[:space:]]*PASS" <<<"$line" \
      || { log_fail "$hook: a real verdict is unreadable — [$line]"; VERDICT_OK=0; }
  done <<EOF
${kind}_VERDICT: PASS
**${kind}_VERDICT: PASS**
  ${kind}_VERDICT: PASS
> **${kind}_VERDICT: PASS**
EOF

  # Must NOT be read: a verdict quoted inside a finding or a diff. This repo
  # reviews a review pipeline, so its own diffs carry these strings constantly.
  while IFS= read -r line; do
    grep -qE "${prefix}${kind}_VERDICT:[[:space:]]*PASS" <<<"$line" \
      && { log_fail "$hook: a quoted verdict is readable as a verdict — [$line]"; VERDICT_OK=0; }
  done <<EOF
-${kind}_VERDICT: PASS
+${kind}_VERDICT: PASS
the report said ${kind}_VERDICT: PASS here
EOF

  # Defined before used, under `set -u`.
  #
  # The first version of this fix referenced the prefix in the "review errored"
  # branch and assigned it sixty lines later, next to the parser. That branch
  # then died on `unbound variable` — the commit was still refused, but by a
  # crash instead of the fail-closed message, and the outcome bookkeeping and
  # failure log never ran. A pattern nothing can expand is worse than a strict
  # one, and it only shows on the error path, which is the path nobody exercises.
  def_line=$(grep -n "^MANTA_VERDICT_PREFIX=" "$hook_file" | head -1 | cut -d: -f1)
  use_line=$(grep -n 'MANTA_VERDICT_PREFIX}' "$hook_file" | head -1 | cut -d: -f1)
  if [[ -z "$def_line" || -z "$use_line" || "$def_line" -gt "$use_line" ]]; then
    log_fail "$hook: MANTA_VERDICT_PREFIX is used at line ${use_line:-?} before it is set at line ${def_line:-never} — under set -u the error path aborts instead of failing closed with a message"
    VERDICT_OK=0
  fi

  # The strictness the guard assumes. Without `set -u` the bug above is a silent
  # empty prefix rather than a crash, which reads as an unanchored match.
  grep -qE '^set -euo pipefail' "$hook_file" \
    || { log_fail "$hook: no 'set -euo pipefail' — an unset prefix would silently match anywhere"; VERDICT_OK=0; }

  # BLOCK is tried before PASS, so a review carrying both refuses. Losing that
  # order turns the safe failure into the unsafe one.
  block_line=$(grep -n "VERDICT=BLOCK" "$hook_file" | head -1 | cut -d: -f1)
  pass_line=$(grep -n "VERDICT=PASS" "$hook_file" | head -1 | cut -d: -f1)
  if [[ -z "$block_line" || -z "$pass_line" || "$block_line" -ge "$pass_line" ]]; then
    log_fail "$hook: BLOCK is no longer resolved before PASS"
    VERDICT_OK=0
  fi
done
[[ $VERDICT_OK -eq 1 ]] \
  && log_ok "both hooks read an emphasised verdict, refuse a quoted one, and try BLOCK first"

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
