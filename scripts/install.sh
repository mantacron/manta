#!/usr/bin/env bash
# Manta Community — Installer
#
# Installs the Manta Community Edition into any project.
# 11 agents · 14 commands · 2 git hooks
# Safe to re-run — existing files are preserved unless --force is passed.
#
# Usage:
#   # From a local clone:
#   bash /path/to/manta-community/scripts/install.sh
#
#   # Force overwrite existing files:
#   bash install.sh --force
#
#   # Install from a specific branch or fork:
#   REPO=your-fork BRANCH=dev bash install.sh

set -euo pipefail

# ─── Config ───────────────────────────────────────────────────────────────────
REPO="${REPO:-your-org/manta}"
BRANCH="${BRANCH:-main}"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
FORCE=false

for arg in "$@"; do
  [[ "$arg" == "--force" ]] && FORCE=true
done

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log_step()  { echo -e "\n${CYAN}${BOLD}▶ $1${RESET}"; }
log_ok()    { echo -e "  ${GREEN}✓${RESET} $1"; }
log_skip()  { echo -e "  ${YELLOW}→${RESET} $1 ${YELLOW}(already exists — skipped)${RESET}"; }
log_warn()  { echo -e "  ${YELLOW}⚠${RESET} $1"; }
log_error() { echo -e "  ${RED}✗${RESET} $1"; }
log_info()  { echo -e "  ${CYAN}ℹ${RESET} $1"; }

# ─── Header ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}${BOLD}║        Manta Community — Installer                 ║${RESET}"
echo -e "${CYAN}${BOLD}║  11 agents · 14 commands · automated code review   ║${RESET}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════╝${RESET}"
echo ""

[[ "$FORCE" == "true" ]] && echo -e "${YELLOW}${BOLD}--force: existing files will be overwritten${RESET}\n"

# ─── Detect run mode ──────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
LOCAL_ROOT=""

if [[ -n "$SCRIPT_DIR" && -d "$SCRIPT_DIR/../.claude/agents" ]]; then
  LOCAL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  log_info "Running from local clone: $LOCAL_ROOT"
else
  log_info "Running via curl — will download files from github.com/${REPO}@${BRANCH}"

  if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
    log_error "curl or wget is required"
    exit 1
  fi
fi

# ─── Helper: copy or download a file ──────────────────────────────────────────
install_file() {
  local src_rel="$1"
  local dst="$2"
  local label="${3:-$dst}"

  if [[ -f "$dst" && "$FORCE" != "true" ]]; then
    log_skip "$label"
    return
  fi

  mkdir -p "$(dirname "$dst")"

  if [[ -n "$LOCAL_ROOT" ]]; then
    cp "$LOCAL_ROOT/$src_rel" "$dst"
  else
    if command -v curl &>/dev/null; then
      curl -fsSL "$BASE_URL/$src_rel" -o "$dst"
    else
      wget -q "$BASE_URL/$src_rel" -O "$dst"
    fi
  fi

  log_ok "$label"
}

# ─── Helper: merge CLAUDE.md ──────────────────────────────────────────────────
install_claude_md() {
  if [[ ! -f "CLAUDE.md" ]]; then
    install_file "CLAUDE.md" "CLAUDE.md"
    return
  fi

  if [[ "$FORCE" == "true" ]]; then
    install_file "CLAUDE.md" "CLAUDE.md" "CLAUDE.md (overwritten)"
    return
  fi

  if grep -q "manta-community" CLAUDE.md 2>/dev/null; then
    log_skip "CLAUDE.md (Manta reference already present)"
    return
  fi

  cat >> CLAUDE.md << 'EOF'

---

## Manta Community — AI Review Pipeline

This project uses [Manta Community](https://github.com/your-org/manta): an 11-agent AI pipeline for automated code review.

**On every `git commit`:** 4 agents review staged changes. CRITICAL findings block the commit.
**On every `git push`:** 4 agents run a full branch review. CRITICAL and WARNING both block.
**Commands available:** `/project:init`, `/project:review`, `/project:security-scan`,
`/project:blueprint`, `/project:scaffold`, `/project:ui`, `/project:fix`, and more.

See `.claude/agents/` and `.claude/commands/` for the full reference.
EOF
  log_ok "CLAUDE.md (Manta reference appended)"
}

# ─── Step 1: Verify working directory ─────────────────────────────────────────
log_step "Checking target directory"

TARGET_DIR="$(pwd)"
log_ok "Target: $TARGET_DIR"

if git rev-parse --git-dir &>/dev/null; then
  log_ok "Git repository detected"
else
  log_warn "Not a git repository — git hooks won't activate until you run: git init"
fi

# ─── Step 2: Install agents ───────────────────────────────────────────────────
log_step "Installing agents (.claude/agents/)"

AGENTS=(
  "security-sentinel"
  "code-quality"
  "perf-analyzer"
  "db-migration-guardian"
  "remediation-agent"
  "scaffolding-agent"
  "code-writer"
  "doc-keeper"
  "pr-summarizer"
  "blueprint-agent"
  "ui-ux-agent"
)

mkdir -p .claude/agents
for agent in "${AGENTS[@]}"; do
  install_file ".claude/agents/${agent}.md" ".claude/agents/${agent}.md" "agents/${agent}.md"
done

# ─── Step 3: Install commands ─────────────────────────────────────────────────
log_step "Installing commands (.claude/commands/)"

COMMANDS=(
  "init"
  "audit"
  "review"
  "pre-commit-review"
  "pre-push-review"
  "generate-tests"
  "update-docs"
  "security-scan"
  "blueprint"
  "fix"
  "scaffold"
  "write"
  "capture-patterns"
  "ui"
)

mkdir -p .claude/commands
for cmd in "${COMMANDS[@]}"; do
  install_file ".claude/commands/${cmd}.md" ".claude/commands/${cmd}.md" "commands/${cmd}.md"
done

# ─── Step 4: Install settings.json ────────────────────────────────────────────
log_step "Installing .claude/settings.json"

if [[ -f ".claude/settings.json" && "$FORCE" != "true" ]]; then
  log_skip ".claude/settings.json"
else
  install_file ".claude/settings.json" ".claude/settings.json"
fi

# ─── Step 5: Install git hooks ────────────────────────────────────────────────
log_step "Installing git hooks (.githooks/)"

mkdir -p .githooks

install_file ".githooks/pre-commit" ".githooks/pre-commit"
install_file ".githooks/pre-push"   ".githooks/pre-push"

chmod +x .githooks/pre-commit .githooks/pre-push
log_ok "Git hooks made executable"

# ─── Step 6: Install setup script ─────────────────────────────────────────────
log_step "Installing scripts/setup.sh"

mkdir -p scripts
install_file "scripts/setup.sh" "scripts/setup.sh"
chmod +x scripts/setup.sh
log_ok "scripts/setup.sh made executable"

# ─── Step 7: Create ui-designs/ folder ───────────────────────────────────────
log_step "Creating ui-designs/ folder"

if [[ -d "ui-designs" ]]; then
  log_skip "ui-designs/ (already exists)"
else
  mkdir -p ui-designs
  cat > ui-designs/README.md << 'EOF'
# ui-designs/

Drop design files here — screenshots, Figma exports, wireframes — and run:

```
/project:ui
```

Manta's `ui-ux-agent` will convert them into responsive, accessible, DRY-compliant
components that match your project's conventions.

Supported formats: PNG, JPG, JPEG, SVG, WEBP, PDF
Companion spec files: add a `.md` file with the same name for written annotations
  (e.g. `checkout.png` + `checkout.md`)
EOF
  log_ok "ui-designs/ created (drop designs here for /project:ui)"
fi

# ─── Step 8: Install / merge CLAUDE.md ────────────────────────────────────────
log_step "Installing CLAUDE.md"
install_claude_md

# ─── Step 8b: Install pattern config templates ───────────────────────────────
log_step "Installing pattern configuration (PATTERNS.md + manta.patterns.json)"

if [[ -f "PATTERNS.md" && "$FORCE" != "true" ]]; then
  log_skip "PATTERNS.md (your patterns are preserved)"
else
  install_file "PATTERNS.md" "PATTERNS.md"
fi

if [[ -f "manta.patterns.json" && "$FORCE" != "true" ]]; then
  log_skip "manta.patterns.json (your patterns are preserved)"
else
  install_file "manta.patterns.json" "manta.patterns.json"
fi

log_info "Run /project:capture-patterns to auto-populate from your codebase"

# ─── Step 8c: Install .mantaignore template ───────────────────────────────────
log_step "Installing .mantaignore"

if [[ -f ".mantaignore" && "$FORCE" != "true" ]]; then
  log_skip ".mantaignore (your suppressions preserved)"
else
  install_file ".mantaignore" ".mantaignore"
fi

# ─── Step 9: Update .gitignore ────────────────────────────────────────────────
log_step "Updating .gitignore"

add_to_gitignore() {
  local entry="$1"
  local comment="$2"
  if [[ -f ".gitignore" ]] && grep -qF "$entry" .gitignore; then
    log_skip ".gitignore: $entry already present"
  else
    printf "\n# %s\n%s\n" "$comment" "$entry" >> .gitignore
    log_ok ".gitignore: added $entry"
  fi
}

[[ ! -f ".gitignore" ]] && touch .gitignore && log_ok ".gitignore created"

add_to_gitignore ".env"              "Environment variables"
add_to_gitignore ".env.local"        "Local env overrides"
add_to_gitignore ".claude/init-state.json" "Claude Code init session state"
add_to_gitignore "reports/*-commit-review.md" "Manta hook logs"
add_to_gitignore "reports/*-push-review.md"   "Manta hook logs"

# ─── Step 10: Configure git hooks path ────────────────────────────────────────
log_step "Configuring git hooks path"

if git rev-parse --git-dir &>/dev/null; then
  GIT_ROOT_DIR="$(git rev-parse --show-toplevel)"
  INSTALL_DIR="$(pwd)"

  if [[ "$GIT_ROOT_DIR" != "$INSTALL_DIR" ]]; then
    MANTA_RELPATH="${INSTALL_DIR#$GIT_ROOT_DIR/}"
    (cd "$GIT_ROOT_DIR" && git config core.hooksPath "${MANTA_RELPATH}/.githooks")
    log_ok "git config core.hooksPath = ${MANTA_RELPATH}/.githooks (set at project root)"
    log_info "Subdirectory mode: Manta is at ${MANTA_RELPATH}/, agents target the parent project"

    if ! grep -q "Manta Subdirectory Mode" CLAUDE.md 2>/dev/null; then
      cat >> CLAUDE.md << EOF

---

## Manta Subdirectory Mode

Manta is installed at \`${MANTA_RELPATH}/\` inside the parent project.
When running commands or agents, **project source files live one level up (\`../\`)**:
- Use \`../\` to reference project files (e.g. \`../src/\`, \`../package.json\`)
- Git operations automatically target the project root via the git environment
EOF
      log_ok "CLAUDE.md updated with subdirectory mode context"
    fi
  else
    git config core.hooksPath .githooks
    log_ok "git config core.hooksPath = .githooks"
  fi
else
  log_warn "Skipped — not a git repo. Run after git init:"
  log_info "  git config core.hooksPath .githooks"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}${BOLD}                 Installation Complete               ${RESET}"
echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "  ${GREEN}${BOLD}✓ 11 agents${RESET}    installed to ${CYAN}.claude/agents/${RESET}"
echo -e "  ${GREEN}${BOLD}✓ 14 commands${RESET}  installed to ${CYAN}.claude/commands/${RESET}"
echo -e "  ${GREEN}${BOLD}✓ 2 git hooks${RESET}  installed to ${CYAN}.githooks/${RESET}"
echo -e "  ${GREEN}${BOLD}✓ PATTERNS.md${RESET}  + ${CYAN}manta.patterns.json${RESET} — pattern enforcement config"
echo -e "  ${GREEN}${BOLD}✓ .mantaignore${RESET} template for suppressing false positives"
echo -e "  ${GREEN}${BOLD}✓ ui-designs/${RESET} folder — drop designs here for ${CYAN}/project:ui${RESET}"
echo ""
echo -e "${BOLD}Next steps:${RESET}"
echo ""
echo -e "  1. Open Claude Code in this project:"
echo -e "     ${CYAN}claude${RESET}"
echo ""
echo -e "  2. Run the setup wizard:"
echo -e "     ${CYAN}/project:init${RESET}"
echo ""
echo -e "  3. Or — start with a security scan on your existing code:"
echo -e "     ${CYAN}/project:security-scan${RESET}"
echo -e "     ${CYAN}/project:blueprint${RESET}   ← visual map of your codebase"
echo ""
echo -e "${BOLD}To update later:${RESET}"
echo -e "  ${CYAN}bash scripts/install.sh --force${RESET}"
echo ""
