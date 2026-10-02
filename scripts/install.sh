#!/usr/bin/env bash
# Manta — Installer
#
# Installs the Manta Edition into any project.
# 20 agents · 21 commands · 2 git hooks
# Safe to re-run — existing files are preserved unless --update or --force is passed.
#
# Usage:
#   # From a local clone:
#   bash /path/to/manta/scripts/install.sh
#
#   # Update an existing install — Manta's files refreshed, yours kept:
#   bash /path/to/manta/scripts/install.sh --update
#
#   # Force overwrite everything, your patterns and suppressions included:
#   bash install.sh --force
#
#   # Install from a specific branch or fork:
#   REPO=your-fork BRANCH=dev bash install.sh

set -euo pipefail

# ─── Config ───────────────────────────────────────────────────────────────────
REPO="${REPO:-mantacron/manta}"
BRANCH="${BRANCH:-main}"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
FORCE=false
UPDATE=false
# Every path install_file wrote this run — the only files the gate may later
# skip as "Manta's own, unchanged" (see the end of this script).
INSTALLER_WROTE=()

for arg in "$@"; do
  [[ "$arg" == "--force" ]] && FORCE=true
  # --update is --force for every file Manta owns and a no-op for every file the
  # developer owns. `--force` was the only documented update, and it replaced
  # their patterns, suppressions and settings with templates and their CLAUDE.md
  # with Manta's own — the README promised those were "never touched".
  [[ "$arg" == "--update" ]] && { FORCE=true; UPDATE=true; }
done

# True when $1 exists and belongs to the developer for this run: always without
# --force, and still under --update. Only a bare --force replaces it.
keep_customer_file() {
  [[ -e "$1" ]] && [[ "$FORCE" != "true" || "$UPDATE" == "true" ]]
}

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
echo -e "${CYAN}${BOLD}║        Manta — Installer                 ║${RESET}"
echo -e "${CYAN}${BOLD}║  20 agents · 21 commands · automated code review   ║${RESET}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════╝${RESET}"
echo ""

if [[ "$UPDATE" == "true" ]]; then
  echo -e "${YELLOW}${BOLD}--update: Manta's files are refreshed; your patterns, suppressions and CLAUDE.md are kept${RESET}\n"
elif [[ "$FORCE" == "true" ]]; then
  echo -e "${YELLOW}${BOLD}--force: existing files will be overwritten — your patterns and suppressions included (use --update to keep them)${RESET}\n"
fi

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
    # Bounded: a stalled connection used to hang the installer indefinitely.
    if command -v curl &>/dev/null; then
      curl -fsSL --connect-timeout 15 --max-time 120 "$BASE_URL/$src_rel" -o "$dst"
    else
      wget -q --timeout=30 --tries=2 "$BASE_URL/$src_rel" -O "$dst"
    fi
  fi

  INSTALLER_WROTE+=("$dst")
  log_ok "$label"
}

# ─── Helper: merge CLAUDE.md ──────────────────────────────────────────────────
install_claude_md() {
  if [[ ! -f "CLAUDE.md" ]]; then
    install_file "CLAUDE.md" "CLAUDE.md"
    return
  fi

  if [[ "$FORCE" == "true" && "$UPDATE" != "true" ]]; then
    install_file "CLAUDE.md" "CLAUDE.md" "CLAUDE.md (overwritten)"
    return
  fi

  # Present means the block's own heading, or Manta's full CLAUDE.md from an
  # earlier install. Any lowercase "manta" used to count — so a CLAUDE.md that
  # merely mentioned .mantaignore, or a project named mantaray, never got the
  # reference block at all.
  if grep -qE '^## Manta — AI Review Pipeline$|^# Manta$' CLAUDE.md 2>/dev/null; then
    log_skip "CLAUDE.md (Manta reference already present)"
    return
  fi

  cat >> CLAUDE.md << 'EOF'

---

## Manta — AI Review Pipeline

This project uses [Manta](https://github.com/mantacron/manta): a 20-agent AI pipeline for automated code review.

**On every `git commit`:** 3 agents review staged changes (db-migration-guardian only when a migration is staged). CRITICAL findings block the commit.
**On every `git push`:** 3–4 agents review the branch diff. CRITICAL and WARNING both block.
**Commands available:** `/init`, `/review`, `/security-scan`,
`/blueprint`, `/scaffold`, `/ui`, `/fix`, and more.

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
  "review-reporter"
  "scaffolding-agent"
  "code-writer"
  "doc-keeper"
  "pr-summarizer"
  "blueprint-agent"
  "ui-component-writer"
  "wiki-agent"
  "requirement-parser"
  "product-manager"
  "ux-planner"
  "senior-software-engineer"
  "technical-cto-advisor"
  "constitutional-validator"
  "documentation-analyst-writer"
)

mkdir -p .claude/agents
for agent in "${AGENTS[@]}"; do
  install_file ".claude/agents/${agent}.md" ".claude/agents/${agent}.md" "agents/${agent}.md"
done

# ─── Step 3: Install commands ─────────────────────────────────────────────────
log_step "Installing commands (.claude/commands/)"

COMMANDS=(
  "init"
  "poc"
  "audit"
  "review"
  "pre-commit-review"
  "pre-push-review"
  "generate-tests"
  "update-docs"
  "security-scan"
  "blueprint"
  "fix"
  "explain"
  "debt"
  "scaffold"
  "write"
  "capture-patterns"
  "ui"
  "wiki"
  "rpi-research"
  "rpi-plan"
  "rpi-implement"
)

mkdir -p .claude/commands
for cmd in "${COMMANDS[@]}"; do
  install_file ".claude/commands/${cmd}.md" ".claude/commands/${cmd}.md" "commands/${cmd}.md"
done

# ─── Step 4: Install settings.json ────────────────────────────────────────────
log_step "Installing .claude/settings.json"

if [[ -f ".claude/settings.json" && "$UPDATE" == "true" ]]; then
  # Manta's permission rules and hooks change between versions (the commit
  # guard among them), so an update takes the new file — but never silently
  # discards a rule the developer added.
  if [[ -n "$LOCAL_ROOT" ]] && cmp -s "$LOCAL_ROOT/.claude/settings.json" ".claude/settings.json"; then
    log_skip ".claude/settings.json (already current)"
  else
    cp ".claude/settings.json" ".claude/settings.json.pre-update"
    install_file ".claude/settings.json" ".claude/settings.json"
    log_warn "Previous settings saved to .claude/settings.json.pre-update — re-apply any rules you added"
  fi
elif [[ -f ".claude/settings.json" && "$FORCE" != "true" ]]; then
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

# ─── Step 6: Install scripts ──────────────────────────────────────────────────
log_step "Installing scripts/"

mkdir -p scripts
install_file "scripts/setup.sh" "scripts/setup.sh"
install_file "scripts/shallow-scan.sh" "scripts/shallow-scan.sh"
install_file "scripts/build-project-map.sh" "scripts/build-project-map.sh"
# The model-policy tool — README documents it as the way to change which model
# each agent runs on, so it has to exist in an installed project.
install_file "scripts/models.sh" "scripts/models.sh"
chmod +x scripts/setup.sh scripts/shallow-scan.sh scripts/build-project-map.sh scripts/models.sh
log_ok "scripts made executable"

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
/ui
```

Manta's `ui-component-writer` will convert them into responsive, accessible, DRY-compliant
components that match your project's conventions.

Supported formats: PNG, JPG, JPEG, SVG, WEBP, PDF
Companion spec files: add a `.md` file with the same name for written annotations
  (e.g. `checkout.png` + `checkout.md`)
EOF
  log_ok "ui-designs/ created (drop designs here for /ui)"
fi

# ─── Step 8: Install / merge CLAUDE.md ────────────────────────────────────────
log_step "Installing CLAUDE.md"
install_claude_md

# ─── Step 8a: Install AI tool instruction files ───────────────────────────────
log_step "Installing AI tool instruction files (AGENTS.md, GEMINI.md, .github/copilot-instructions.md)"

# Under --update only Manta's own copies are refreshed. AGENTS.md in particular
# is a cross-tool convention a project may well have written for itself; the
# first install skipped it, and an update must not then replace it. Manta's
# copies are recognised by their first line.
install_instruction_file() {  # $1 = path, $2 = Manta's first line (ERE)
  if [[ "$UPDATE" == "true" && -e "$1" ]] && ! head -n 1 "$1" 2>/dev/null | grep -qE "$2"; then
    log_skip "$1 (your own, not Manta's — kept)"
  else
    install_file "$1" "$1"
  fi
}
install_instruction_file "AGENTS.md" '^# Manta — AI Review Pipeline$'
install_instruction_file "GEMINI.md" '^# Manta — AI Review Pipeline$'

mkdir -p .github
install_instruction_file ".github/copilot-instructions.md" '^# Copilot Instructions — Manta$'

# ─── Step 8b: Install pattern config templates ───────────────────────────────
log_step "Installing pattern configuration (PATTERNS.md + manta.patterns.json)"

if keep_customer_file "PATTERNS.md"; then
  log_skip "PATTERNS.md (your patterns are preserved)"
else
  install_file "PATTERNS.md" "PATTERNS.md"
fi

if keep_customer_file "manta.patterns.json"; then
  log_skip "manta.patterns.json (your patterns are preserved)"
else
  install_file "manta.patterns.json" "manta.patterns.json"
fi

log_info "Run /capture-patterns to auto-populate from your codebase"

# ─── Step 8c: Install .mantaignore template ───────────────────────────────────
log_step "Installing .mantaignore"

if keep_customer_file ".mantaignore"; then
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
add_to_gitignore ".manta-cache/"     "Manta local cache (project map, scan signals)"
# A local backup, not project state — and an update closes by suggesting
# `git add .claude`, which would otherwise commit it.
add_to_gitignore ".claude/settings.json.pre-update" "Manta: your previous settings, kept by install.sh --update"

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

    if ! grep -q "Subdirectory Mode" CLAUDE.md 2>/dev/null; then
      cat >> CLAUDE.md << EOF

---

## Manta Subdirectory Mode

Manta is installed at \`${MANTA_RELPATH}/\` inside the parent project.
All agents and commands must target the **parent directory** for project files — not the \`${MANTA_RELPATH}/\` folder itself.

**Rules when in subdirectory mode:**
- All file creation (spec, architecture, scaffold, reports, etc.) goes to \`../\` — the parent project root
- All file reads (source code, package.json, existing specs) use \`../\` as the base
- Git operations (staged files, diffs, log) target the parent automatically via the git environment
- **Never create project artifacts inside the \`${MANTA_RELPATH}/\` folder itself**

**Path translation:**
| Instead of | Use |
|---|---|
| \`spec/SPEC.md\` | \`../spec/SPEC.md\` |
| \`src/\` | \`../src/\` |
| \`package.json\` | \`../package.json\` |
| \`reports/\` | \`../reports/\` |
| \`docs/BLUEPRINT.md\` | \`../docs/BLUEPRINT.md\` |
| \`ARCHITECTURE.md\` | \`../ARCHITECTURE.md\` |
| \`.env.example\` | \`../.env.example\` |
| \`README.md\` | \`../README.md\` |
| \`PATTERNS.md\` | \`../PATTERNS.md\` |
| \`manta.patterns.json\` | \`../manta.patterns.json\` |
| \`.mantaignore\` | \`../.mantaignore\` |

This applies to every agent and every command — \`/init\`, \`/scaffold\`, \`/write\`, \`/audit\`, \`/blueprint\`, and all others.
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

# ─── What this run wrote, byte for byte ───────────────────────────────────────
# The install or update commit is the one commit that carries Manta's own files,
# and the gate would review every one of them — some forty agent and command
# files, the hooks and the scripts — on the developer's own AI bill, at commit
# and again at push. The hooks skip a file only while its staged content is
# still the exact blob recorded here, so an edit to an installed file is
# reviewed like any other change.
#
# Kept in .manta-cache (git-ignored, local to this machine), never committed: a
# hash a teammate could commit is a hash a teammate could forge, and this list
# must only ever say "the installer on this machine wrote exactly this". A clone
# without it — another developer, CI — reviews the update in full.
if git rev-parse --git-dir &>/dev/null; then
  mkdir -p .manta-cache
  INSTALLED_BLOBS=".manta-cache/installed-blobs.tsv"
  # Paths as git names them: relative to the repository root, which in
  # subdirectory mode is not this directory.
  _prefix="$(git rev-parse --show-prefix 2>/dev/null || true)"
  # Temp files and awk rather than associative arrays: macOS ships bash 3.2.
  _kept="$(mktemp)"; _fresh="$(mktemp)"
  # An entry from an earlier run survives only while the file still holds the
  # blob recorded then — a file edited since, and kept by this run, drops out.
  if [[ -f "$INSTALLED_BLOBS" && ! -L "$INSTALLED_BLOBS" ]]; then
    while IFS=$'\t' read -r _blob _path; do
      _local="${_path#"$_prefix"}"
      [[ -n "$_blob" && -f "$_local" ]] || continue
      [[ "$(git hash-object -- "$_local" 2>/dev/null)" == "$_blob" ]] \
        && printf '%s\t%s\n' "$_blob" "$_path" >> "$_kept"
    done < "$INSTALLED_BLOBS"
  fi
  # Only what this run wrote. Hashing whatever is on disk would vouch for a file
  # the installer skipped because the developer already had their own.
  for _path in ${INSTALLER_WROTE[@]+"${INSTALLER_WROTE[@]}"}; do
    [[ -f "$_path" ]] || continue
    _blob="$(git hash-object -- "$_path" 2>/dev/null)" || continue
    printf '%s\t%s%s\n' "$_blob" "$_prefix" "$_path" >> "$_fresh"
  done
  # Fresh entries win; kept ones fill in the paths this run did not rewrite.
  awk -F'\t' 'NR == FNR { seen[$2] = 1; print; next } !($2 in seen)' "$_fresh" "$_kept" > "$INSTALLED_BLOBS.tmp"
  rm -f "$_kept" "$_fresh"
  mv "$INSTALLED_BLOBS.tmp" "$INSTALLED_BLOBS"
  log_ok "$INSTALLED_BLOBS — Manta's files exactly as installed, skipped by the gate until edited"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}${BOLD}                 Installation Complete               ${RESET}"
echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "  ${GREEN}${BOLD}✓ ${#AGENTS[@]} agents${RESET}    installed to ${CYAN}.claude/agents/${RESET}"
echo -e "  ${GREEN}${BOLD}✓ ${#COMMANDS[@]} commands${RESET}  installed to ${CYAN}.claude/commands/${RESET}"
echo -e "  ${GREEN}${BOLD}✓ 2 git hooks${RESET}  installed to ${CYAN}.githooks/${RESET} (claude · codex · gemini)"
echo -e "  ${GREEN}${BOLD}✓ PATTERNS.md${RESET}  + ${CYAN}manta.patterns.json${RESET} — pattern enforcement config"
echo -e "  ${GREEN}${BOLD}✓ .mantaignore${RESET} template for suppressing false positives"
echo -e "  ${GREEN}${BOLD}✓ ui-designs/${RESET} folder — drop designs here for ${CYAN}/ui${RESET}"
echo -e "  ${GREEN}${BOLD}✓ AGENTS.md${RESET}    — instruction file for OpenAI Codex CLI"
echo -e "  ${GREEN}${BOLD}✓ GEMINI.md${RESET}    — instruction file for Google Gemini CLI"
echo -e "  ${GREEN}${BOLD}✓ copilot-instructions.md${RESET} — instruction file for GitHub Copilot"
echo ""
if [[ "$UPDATE" == "true" ]]; then
  # An update is a change to review and commit, not a first run of /init.
  echo -e "${BOLD}Updated.${RESET} Review the change and commit it:"
  echo -e "  ${CYAN}git status && git diff --stat${RESET}"
  echo -e "  ${CYAN}git add .claude .githooks scripts CLAUDE.md AGENTS.md GEMINI.md .github .gitignore && git commit -m \"chore: update Manta\"${RESET}"
  echo ""
else
  echo -e "${BOLD}Next steps:${RESET}"
  echo ""
  echo -e "  1. Open Claude Code in this project:"
  echo -e "     ${CYAN}claude${RESET}"
  echo ""
  echo -e "  2. Run the setup wizard:"
  echo -e "     ${CYAN}/init${RESET}"
  echo ""
  echo -e "  3. Or — start with a security scan on your existing code:"
  echo -e "     ${CYAN}/security-scan${RESET}"
  echo -e "     ${CYAN}/blueprint${RESET}   ← visual map of your codebase"
  echo ""
fi
# The installer is not copied into the project, so "bash scripts/install.sh"
# named a script the developer did not have. The clone goes to a private
# mktemp directory: a fixed /tmp/manta is a path another local user can create
# first, and then the script that runs is theirs.
echo -e "${BOLD}To update later${RESET} (run the installer from a fresh clone of Manta):"
echo -e "  ${CYAN}d=\$(mktemp -d) && gh repo clone mantacron/manta \"\$d\" && bash \"\$d/scripts/install.sh\" --update; rm -rf \"\$d\"${RESET}"
echo -e "  ${CYAN}--update${RESET} refreshes Manta's files and keeps your patterns, suppressions and CLAUDE.md."
echo ""
