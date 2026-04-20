#!/usr/bin/env bash
# Build a lightweight project relationship map from source files.
# Cached per git commit hash — auto-invalidates when HEAD changes.
# Output: .cathy-cache/project-map.json
#
# Usage: bash scripts/build-project-map.sh [--force]
# Called by pre-commit hook; agents read the cached map for context-efficient review.

set -euo pipefail

CACHE_DIR=".cathy-cache"
MAP_FILE="$CACHE_DIR/project-map.json"
HASH_FILE="$CACHE_DIR/project-map.hash"
FORCE="${1:-}"

mkdir -p "$CACHE_DIR"

# ─── Cache check ─────────────────────────────────────────────────────────────
CURRENT_HASH=$(git rev-parse HEAD 2>/dev/null || echo "no-git")

if [[ "$FORCE" != "--force" ]] && [[ -f "$MAP_FILE" ]] && [[ -f "$HASH_FILE" ]]; then
  CACHED_HASH=$(cat "$HASH_FILE" 2>/dev/null || echo "")
  if [[ "$CURRENT_HASH" == "$CACHED_HASH" ]]; then
    echo "✓ project-map cache hit (${CURRENT_HASH:0:7})" >&2
    cat "$MAP_FILE"
    exit 0
  fi
fi

echo "↳ Building project map (${CURRENT_HASH:0:7})..." >&2

# ─── Exclusion patterns ───────────────────────────────────────────────────────
EXCLUDE_DIRS="node_modules|vendor|dist|build|out|.next|.nuxt|__pycache__|.venv|venv|target|.gradle|coverage|.nyc_output|.git|pentesting|reports|.cathy-cache"

# ─── File discovery ───────────────────────────────────────────────────────────
SOURCE_FILES=$(find . -type f \
  \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
  -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" \
  -o -name "*.rb" -o -name "*.php" -o -name "*.cs" -o -name "*.kt" \) \
  | grep -vE "/(${EXCLUDE_DIRS})/" \
  | sort 2>/dev/null || true)

TEST_FILES=$(echo "$SOURCE_FILES" | grep -E '(test|spec|__tests__|_test\.|\.test\.|\.spec\.)' || true)
API_FILES=$(echo "$SOURCE_FILES" | grep -iE '(route|controller|handler|endpoint|view|api)' || true)
AUTH_FILES=$(echo "$SOURCE_FILES" | grep -iE '(auth|login|session|jwt|token|oauth|permission|role)' || true)
PAYMENT_FILES=$(echo "$SOURCE_FILES" | grep -iE '(payment|billing|stripe|charge|invoice|subscription)' || true)
DB_FILES=$(echo "$SOURCE_FILES" | grep -iE '(model|repository|dao|schema|migration|prisma|orm|query)' || true)
MIGRATION_FILES=$(find . -type f \
  \( -name "*.sql" -o -name "schema.prisma" \) \
  -path "*/migration*" \
  | grep -vE "/(${EXCLUDE_DIRS})/" 2>/dev/null || true)
MIGRATION_FILES+=$(find . -type f -name "*.py" -path "*/migrations/*" \
  | grep -vE "/(${EXCLUDE_DIRS})/" 2>/dev/null || true)

FILE_COUNT=$(echo "$SOURCE_FILES" | grep -c . 2>/dev/null || echo 0)

# ─── Import/dependency extraction (fast grep-based) ──────────────────────────
# Build import map: for each file, list what it imports from the project
declare -A IMPORT_MAP

build_imports() {
  local file="$1"
  local imports=""

  # Python: from X import / import X
  if [[ "$file" == *.py ]]; then
    imports=$(grep -E "^(from|import)\s+\." "$file" 2>/dev/null \
      | sed 's/from \.\(.*\) import.*/\1/; s/import \.\(.*\)/\1/' \
      | head -10 || true)
  fi
  # JS/TS: import from / require
  if [[ "$file" == *.ts || "$file" == *.tsx || "$file" == *.js || "$file" == *.jsx ]]; then
    imports=$(grep -E "^(import|const|let|var).*from ['\"]\.\.?/" "$file" 2>/dev/null \
      | grep -oE "'[^']+'" | tr -d "'" \
      | head -10 || true)
  fi
  # Go: import "path"
  if [[ "$file" == *.go ]]; then
    imports=$(grep -E '"\./' "$file" 2>/dev/null | grep -oE '"[^"]+"' | tr -d '"' | head -10 || true)
  fi

  echo "$imports"
}

# ─── High-risk file classification ───────────────────────────────────────────
HIGH_RISK_FILES=$(echo "$AUTH_FILES"$'\n'"$PAYMENT_FILES" | sort -u | grep -v "^$" || true)

# ─── Entry point detection ───────────────────────────────────────────────────
ENTRY_POINTS=$(find . -maxdepth 3 -type f \
  \( -name "main.py" -o -name "app.py" -o -name "server.py" -o -name "wsgi.py" \
  -o -name "main.go" -o -name "main.ts" -o -name "index.ts" -o -name "index.js" \
  -o -name "app.ts" -o -name "server.ts" -o -name "server.js" \) \
  | grep -vE "/(${EXCLUDE_DIRS})/" 2>/dev/null || true)

# ─── File size map (line count as proxy) ─────────────────────────────────────
declare -A FILE_LINES
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  lc=$(wc -l < "$f" 2>/dev/null || echo 0)
  FILE_LINES["$f"]=$lc
done <<< "$SOURCE_FILES"

# ─── Detect stack ─────────────────────────────────────────────────────────────
STACK_LANGS=""
[[ -f "package.json" ]] && STACK_LANGS+="javascript/typescript "
[[ -f "requirements.txt" || -f "pyproject.toml" || -f "Pipfile" ]] && STACK_LANGS+="python "
[[ -f "go.mod" ]] && STACK_LANGS+="go "
[[ -f "Gemfile" ]] && STACK_LANGS+="ruby "
[[ -f "Cargo.toml" ]] && STACK_LANGS+="rust "
[[ -f "pom.xml" || -f "build.gradle" ]] && STACK_LANGS+="java "

# ─── Write JSON ───────────────────────────────────────────────────────────────
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

python3 - << PYEOF > "$MAP_FILE"
import json, os

def to_list(s):
    return [x for x in s.strip().split('\n') if x] if s.strip() else []

data = {
    "generated_at": "$TIMESTAMP",
    "commit": "$CURRENT_HASH",
    "stack": "$STACK_LANGS".strip().split(),
    "file_count": int("$FILE_COUNT") if "$FILE_COUNT".isdigit() else 0,
    "entry_points":    to_list("""$ENTRY_POINTS"""),
    "high_risk_files": to_list("""$HIGH_RISK_FILES"""),
    "api_files":       to_list("""$API_FILES"""),
    "auth_files":      to_list("""$AUTH_FILES"""),
    "payment_files":   to_list("""$PAYMENT_FILES"""),
    "db_files":        to_list("""$DB_FILES"""),
    "migration_files": to_list("""$MIGRATION_FILES"""),
    "test_files":      to_list("""$TEST_FILES"""),
}

print(json.dumps(data, indent=2))
PYEOF

# ─── Save hash ────────────────────────────────────────────────────────────────
echo "$CURRENT_HASH" > "$HASH_FILE"
echo "✓ Project map written to $MAP_FILE ($FILE_COUNT files)" >&2

cat "$MAP_FILE"
