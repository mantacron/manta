#!/usr/bin/env bash
# Manta — Model Policy Tool
#
# Every agent declares its model in the `model:` field of its own
# `.claude/agents/<name>.md` frontmatter. That field is the single source of
# truth: Claude Code reads it when it spawns the agent, and it **overrides**
# whatever `--model` the caller passed. That is not a bug, but it surprised us
# expensively — the git hooks pass `--model sonnet` and three agents were pinned
# to `opus`, so every commit ran three Opus agents and the flag that looked like
# the cost control governed only the orchestrator.
#
# This script exists so changing a model is one obvious command instead of an
# archaeology exercise across every agent file and both editions.
#
# Usage:
#   bash scripts/models.sh                      # show every agent's model
#   bash scripts/models.sh code-quality haiku   # set one agent, both editions
#   bash scripts/models.sh --hooks sonnet       # set every agent the git hooks run
#   bash scripts/models.sh --check              # exit 1 if any agent is unset
#
# Valid models: inherit | haiku | sonnet | opus | <full model id>
#
# `inherit` means "use whatever model invoked me" — in a git hook that is
# `MANTA_MODEL` (default sonnet), in an interactive session it is the model you
# chose. It is the right setting for anything on the hook path, because it makes
# `MANTA_MODEL=opus git commit` actually work.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colours come from the shared library in the enterprise tree. The community
# tree has no scripts/lib/, and this file is pass-through between the two, so
# the fallback is not defensive padding — it is what makes one copy work in both
# editions. Same TTY rule either way: colour only when stdout is a terminal.
_MANTA_LOG_LIB="$SCRIPT_DIR/lib/manta-log.sh"
if [[ -r "$_MANTA_LOG_LIB" ]]; then
  # shellcheck source=lib/manta-log.sh
  source "$_MANTA_LOG_LIB"
elif [[ "${MANTA_COLOR:-}" != "0" ]] && { [[ "${MANTA_COLOR:-}" == "1" ]] || [[ -t 1 ]]; }; then
  RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
else
  RED=''; YELLOW=''; GREEN=''; CYAN=''; BOLD=''; DIM=''; RESET=''
fi

# Both editions, when the community tree is present. A model change that lands
# in only one of them is exactly the drift `check-agent-copies.sh` exists to
# catch, so do not make the user remember.
TREES=("$ROOT")
[[ -d "$ROOT/community/.claude/agents" ]] && TREES+=("$ROOT/community")

# Agents the git hooks invoke. Kept here rather than derived, because it is a
# policy statement ("these run on every commit or push") and deriving it from
# the command files would silently shrink if a command were reworded.
HOOK_AGENTS=(
  security-sentinel code-quality perf-analyzer db-migration-guardian review-reporter
  spec-guardian test-architect compliance-guardian compliance-scanner
  observability-guardian zero-trust-guardian
)

valid_model() {
  case "$1" in
    inherit|haiku|sonnet|opus) return 0 ;;
    claude-*) return 0 ;;   # full model id, e.g. claude-haiku-4-5-20251001
    *) return 1 ;;
  esac
}

model_of() {
  # Prints the agent's declared model, or `<unset>`. An unset field is not the
  # same as `inherit`: it behaves the same today, but it reads as an oversight
  # and `--check` flags it so the policy stays explicit.
  local file="$1" m
  m=$(grep -m1 '^model:[[:space:]]*' "$file" 2>/dev/null | sed 's/^model:[[:space:]]*//' | tr -d '[:space:]' || true)
  printf '%s' "${m:-<unset>}"
}

list_models() {
  local tree agents_dir f name model
  for tree in "${TREES[@]}"; do
    agents_dir="$tree/.claude/agents"
    [[ -d "$agents_dir" ]] || continue
    echo ""
    echo -e "${BOLD}${tree/#$ROOT/.}${RESET}"
    for f in "$agents_dir"/*.md; do
      [[ -e "$f" ]] || continue
      name="$(basename "$f" .md)"
      model="$(model_of "$f")"
      case "$model" in
        opus)     printf "  %-30s ${YELLOW}%s${RESET}\n" "$name" "$model" ;;
        '<unset>') printf "  %-30s ${RED}%s${RESET}\n" "$name" "$model" ;;
        *)        printf "  %-30s ${GREEN}%s${RESET}\n" "$name" "$model" ;;
      esac
    done
  done
  echo ""
  echo -e "${DIM}inherit = follows the caller: MANTA_MODEL in a git hook (default sonnet),"
  echo -e "your session model interactively. Change one: bash scripts/models.sh <agent> <model>${RESET}"
}

set_model() {
  local name="$1" model="$2" tree f current changed=0 found=0
  for tree in "${TREES[@]}"; do
    f="$tree/.claude/agents/$name.md"
    [[ -f "$f" ]] || continue
    found=1
    current="$(model_of "$f")"
    if [[ "$current" == "$model" ]]; then
      echo -e "  ${DIM}=${RESET} ${tree/#$ROOT/.}: already $model"
      continue
    fi
    if [[ "$current" == "<unset>" ]]; then
      # Insert after the description line so frontmatter ordering stays stable.
      # `sed` on the first `^description:` only — some descriptions are long but
      # none wrap, so a line-anchored match is exact.
      sed -i "0,/^description:.*$/s//&\nmodel: $model/" "$f"
    else
      sed -i "0,/^model:[[:space:]]*.*$/s//model: $model/" "$f"
    fi
    echo -e "  ${GREEN}✓${RESET} ${tree/#$ROOT/.}: $current -> $model"
    changed=1
  done
  if [[ $found -eq 0 ]]; then
    echo -e "${RED}✗${RESET} no agent named '$name' in any tree" >&2
    echo "  available: $(basename -s .md -a "$ROOT/.claude/agents/"*.md | tr '\n' ' ')" >&2
    return 1
  fi
  return 0
}

check_unset() {
  local tree f name bad=0
  for tree in "${TREES[@]}"; do
    for f in "$tree/.claude/agents/"*.md; do
      [[ -e "$f" ]] || continue
      name="$(basename "$f" .md)"
      if [[ "$(model_of "$f")" == "<unset>" ]]; then
        echo -e "  ${RED}✗${RESET} ${tree/#$ROOT/.}: $name has no model: field"
        bad=1
      fi
    done
  done
  if [[ $bad -eq 0 ]]; then
    echo -e "  ${GREEN}✓${RESET} every agent declares a model"
  else
    echo ""
    echo "  An unset model resolves to the caller's, which inside a git hook means" >&2
    echo "  sonnet — fine, but it should say so. Set it explicitly:" >&2
    echo "    bash scripts/models.sh <agent> inherit" >&2
  fi
  return $bad
}

echo ""
echo -e "${CYAN}${BOLD}Manta — Model Policy${RESET}"

case "${1:-}" in
  ''|--list|-l)
    list_models
    ;;
  --check)
    echo ""
    check_unset
    ;;
  --hooks)
    model="${2:-}"
    if [[ -z "$model" ]] || ! valid_model "$model"; then
      echo -e "${RED}✗${RESET} usage: bash scripts/models.sh --hooks <inherit|haiku|sonnet|opus>" >&2
      exit 2
    fi
    echo ""
    echo "Setting every hook-path agent to '$model':"
    for a in "${HOOK_AGENTS[@]}"; do
      # The list is the enterprise roster; community ships a subset. A missing
      # agent is a different edition, not an error.
      [[ -f "$ROOT/.claude/agents/$a.md" ]] || continue
      echo "$a:"
      set_model "$a" "$model" || true
    done
    ;;
  -h|--help)
    sed -n '3,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    ;;
  *)
    name="$1"
    model="${2:-}"
    if [[ -z "$model" ]]; then
      echo -e "${RED}✗${RESET} usage: bash scripts/models.sh <agent> <inherit|haiku|sonnet|opus>" >&2
      exit 2
    fi
    if ! valid_model "$model"; then
      echo -e "${RED}✗${RESET} '$model' is not a valid model" >&2
      echo "  valid: inherit, haiku, sonnet, opus, or a full id like claude-haiku-4-5-20251001" >&2
      exit 2
    fi
    echo ""
    set_model "$name" "$model"
    ;;
esac
echo ""
