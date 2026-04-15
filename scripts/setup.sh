#!/usr/bin/env bash
# Manta Community — Setup Script
# Configures git hooks, validates environment, and prepares the project.

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

ERRORS=0
WARNINGS=0

log_step()    { echo -e "${CYAN}${BOLD}▶ $1${RESET}"; }
log_ok()      { echo -e "  ${GREEN}✓${RESET} $1"; }
log_warn()    { echo -e "  ${YELLOW}⚠${RESET} $1"; ((WARNINGS++)) || true; }
log_error()   { echo -e "  ${RED}✗${RESET} $1"; ((ERRORS++)) || true; }
log_info()    { echo -e "  ${CYAN}ℹ${RESET} $1"; }

# ─── Header ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}${BOLD}║        Manta Community — Setup                     ║${RESET}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════╝${RESET}"
echo ""

# ─── Step 1: Check we're in a git repo ────────────────────────────────────────
log_step "Checking git repository"
if ! git rev-parse --git-dir &>/dev/null; then
  log_error "Not a git repository. Run: git init"
  exit 1
fi
log_ok "Git repository found"

# ─── Step 2: Configure git hooks ──────────────────────────────────────────────
log_step "Configuring git hooks"

HOOKS_DIR=".githooks"
if [[ ! -d "$HOOKS_DIR" ]]; then
  log_error "Hooks directory '$HOOKS_DIR' not found — run install.sh first"
  exit 1
fi

chmod +x "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-push"
log_ok "Hook scripts made executable"

git config core.hooksPath "$HOOKS_DIR"
log_ok "Git configured to use .githooks/ (git config core.hooksPath .githooks)"

# ─── Step 3: Check Claude CLI ─────────────────────────────────────────────────
log_step "Checking Claude Code CLI"

if command -v claude &>/dev/null; then
  CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "unknown")
  log_ok "Claude CLI found: $CLAUDE_VERSION"
else
  log_warn "Claude CLI not found — hooks will warn but won't block commits"
  log_info "Install: npm install -g @anthropic-ai/claude-code"
  log_info "Or: https://claude.ai/code"
fi

# ─── Step 4: Detect tech stack and check tools ────────────────────────────────
log_step "Detecting tech stack"

STACK_DETECTED=false

# Node.js
if [[ -f "package.json" ]]; then
  STACK_DETECTED=true
  log_ok "Node.js project detected (package.json)"
  command -v node &>/dev/null && log_ok "  node: $(node --version)" || log_warn "  node not found"
  command -v npm &>/dev/null && log_ok "  npm: $(npm --version)" || true
  command -v pnpm &>/dev/null && log_ok "  pnpm: $(pnpm --version)" || true
  [[ -f "package-lock.json" || -f "yarn.lock" || -f "pnpm-lock.yaml" ]] \
    && log_ok "  Lock file found — dependency audit enabled" \
    || log_warn "  No lock file found — run your package manager to generate one"
fi

# Python
if [[ -f "requirements.txt" || -f "pyproject.toml" || -f "Pipfile" ]]; then
  STACK_DETECTED=true
  log_ok "Python project detected"
  command -v python3 &>/dev/null && log_ok "  python: $(python3 --version)" || log_warn "  python3 not found"
  command -v pip-audit &>/dev/null \
    && log_ok "  pip-audit: available (dependency audit enabled)" \
    || log_warn "  pip-audit not found — install: pip install pip-audit"
fi

# Go
if [[ -f "go.mod" ]]; then
  STACK_DETECTED=true
  log_ok "Go project detected"
  command -v go &>/dev/null && log_ok "  go: $(go version)" || log_warn "  go not found"
  command -v govulncheck &>/dev/null \
    && log_ok "  govulncheck: available" \
    || log_warn "  govulncheck not found — install: go install golang.org/x/vuln/cmd/govulncheck@latest"
fi

# Rust
if [[ -f "Cargo.toml" ]]; then
  STACK_DETECTED=true
  log_ok "Rust project detected"
  command -v cargo &>/dev/null && log_ok "  cargo: $(cargo --version)" || log_warn "  cargo not found"
  command -v cargo-audit &>/dev/null \
    && log_ok "  cargo-audit: available" \
    || log_warn "  cargo-audit not found — install: cargo install cargo-audit"
fi

# Ruby
if [[ -f "Gemfile" ]]; then
  STACK_DETECTED=true
  log_ok "Ruby project detected"
  command -v ruby &>/dev/null && log_ok "  ruby: $(ruby --version)" || log_warn "  ruby not found"
  (command -v bundle &>/dev/null && bundle exec bundle-audit version &>/dev/null 2>&1) \
    && log_ok "  bundler-audit: available" \
    || log_warn "  bundler-audit not found — install: gem install bundler-audit"
fi

[[ "$STACK_DETECTED" == "false" ]] \
  && log_warn "No recognized tech stack detected — add your dependencies to enable language-specific checks"

# ─── Step 5: Check GitHub CLI (for PR features) ───────────────────────────────
log_step "Checking GitHub CLI (optional, for PR features)"

if command -v gh &>/dev/null; then
  log_ok "gh CLI found: $(gh --version | head -1)"
  gh auth status &>/dev/null 2>&1 \
    && log_ok "  gh authenticated" \
    || { log_warn "  gh not authenticated — run: gh auth login"; log_info "  Needed for: /project:pr-sync"; }
else
  log_info "gh CLI not found — PR auto-posting won't work (manual copy-paste still works)"
  log_info "Install: https://cli.github.com"
fi

# ─── Step 6: Check .env setup ─────────────────────────────────────────────────
log_step "Checking .env setup"

if [[ ! -f ".env.example" && ! -f ".env" ]]; then
  log_info "No .env.example found — creating a template"
  cat > .env.example << 'EOF'
# Environment Variables Template
# Copy to .env and fill in values
# NEVER commit .env to git

NODE_ENV=development
PORT=3000
DATABASE_URL=postgresql://user:password@localhost:5432/dbname
JWT_SECRET=your-secret-here-min-32-chars
EOF
  log_ok ".env.example created"
fi

if [[ -f ".gitignore" ]]; then
  grep -qE '^\.env$|^\.env\b' .gitignore && log_ok ".gitignore covers .env files" || {
    printf "\n# Environment\n.env\n.env.local\n" >> .gitignore
    log_ok ".env added to .gitignore"
  }
else
  log_warn "No .gitignore found — run /project:init to generate one"
fi

# ─── Step 7: Verify hook configuration ────────────────────────────────────────
log_step "Verifying hook configuration"

CONFIGURED_HOOKS_PATH=$(git config core.hooksPath 2>/dev/null || echo "")
[[ "$CONFIGURED_HOOKS_PATH" == ".githooks" ]] \
  && log_ok "git core.hooksPath = .githooks ✓" \
  || log_error "git core.hooksPath not set correctly (got: '$CONFIGURED_HOOKS_PATH')"

[[ -x ".githooks/pre-commit" ]] && log_ok ".githooks/pre-commit is executable ✓" || log_error ".githooks/pre-commit is not executable"
[[ -x ".githooks/pre-push"   ]] && log_ok ".githooks/pre-push is executable ✓"   || log_error ".githooks/pre-push is not executable"

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}${BOLD}                   Setup Summary                    ${RESET}"
echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════${RESET}"
echo ""

if [[ $ERRORS -gt 0 ]]; then
  echo -e "${RED}${BOLD}✗ Setup completed with ${ERRORS} error(s)${RESET}"
  echo -e "  Fix the errors above and run setup again."
elif [[ $WARNINGS -gt 0 ]]; then
  echo -e "${YELLOW}${BOLD}⚠ Setup completed with ${WARNINGS} warning(s)${RESET}"
  echo -e "  Address the warnings above when possible."
else
  echo -e "${GREEN}${BOLD}✅ Setup complete — all checks passed!${RESET}"
fi

echo ""
echo -e "${BOLD}Next steps:${RESET}"
echo -e "  1. Open Claude Code in your project: ${CYAN}claude${RESET}"
echo -e "  2. Run ${CYAN}/project:init${RESET} to finish setup"
echo -e "  3. Start coding — agents review on every ${CYAN}git commit${RESET}"
echo ""
echo -e "${BOLD}Bypass hooks when needed:${RESET}"
echo -e "  ${CYAN}SKIP_MANTA_REVIEW=1 git commit${RESET}       # bypass pre-commit hook"
echo -e "  ${CYAN}SKIP_MANTA_PUSH_REVIEW=1 git push${RESET}    # bypass pre-push hook"
echo ""

exit $ERRORS
