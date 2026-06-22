---
description: Scan the existing codebase and auto-generate PATTERNS.md with detected conventions. Run once, review the output, then commit it so all agents enforce your team's patterns.
---

**Begin by outputting:** `[ Manta Enterprise — Capture Patterns ]`

You are scanning this codebase to detect and document its coding patterns.

Your output is `PATTERNS.md` — the machine-readable pattern registry that `code-quality` enforces at pre-commit and `scaffolding-agent` uses when generating new code.

## Step 1: Check if pattern files already exist

```bash
cat manta.patterns.json 2>/dev/null
cat PATTERNS.md 2>/dev/null | head -20
```

If either file exists with non-null/non-`[none defined]` content, ask the user:
> "Pattern files already have content. Do you want to [overwrite] with a fresh scan, [update] only the empty sections, or [cancel]?"

Proceed based on their answer.

## Step 2: Detect the language and framework stack

```bash
ls package.json go.mod requirements.txt Cargo.toml pom.xml build.gradle composer.json Gemfile 2>/dev/null
head -5 package.json 2>/dev/null
```

Also check `.claude/agents/` for any existing blueprint or architecture notes:
```bash
cat docs/BLUEPRINT.md 2>/dev/null | head -60
cat docs/ARCHITECTURE.md 2>/dev/null | head -60
```

## Step 3: Detect file naming conventions

```bash
# Source files — what casing style?
find . -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" -o -name "*.rb" 2>/dev/null \
  | grep -v node_modules | grep -v vendor | grep -v dist | grep -v build | grep -v ".git" \
  | grep -v __pycache__ | grep -v venv | grep -v target | grep -v coverage \
  | head -30

# Test files — where do they live and what are they named?
find . \( -name "*.test.ts" -o -name "*.spec.ts" -o -name "*.test.js" -o -name "*_test.go" \
  -o -name "test_*.py" -o -name "*_spec.rb" \) 2>/dev/null \
  | grep -v node_modules | grep -v vendor | head -20
```

## Step 4: Detect folder structure

```bash
# Top-level src structure
find . -maxdepth 3 -type d \
  | grep -v node_modules | grep -v vendor | grep -v dist | grep -v build \
  | grep -v ".git" | grep -v __pycache__ | grep -v venv | grep -v target \
  | grep -v coverage | grep -v ".gradle" | grep -v Pods \
  | sort | head -60
```

Infer the architectural pattern: MVC, layered (controllers/services/repositories), feature folders, monorepo, etc.

## Step 5: Detect import style

```bash
# Sample 20 import lines
grep -rn "^import\|^from\|^require\|^use " \
  --include="*.ts" --include="*.js" --include="*.py" --include="*.go" \
  --exclude-dir={node_modules,vendor,dist,build,.git,__pycache__,venv} \
  . 2>/dev/null | head -40
```

Look for: absolute vs relative, path aliases (`@/`, `~/`), barrel files (`index.ts`), import ordering.

## Step 6: Detect function and class naming

```bash
# Function declarations
grep -rn "^function \|^  function \|^export function \|^export const \|^def \|^func " \
  --include="*.ts" --include="*.js" --include="*.py" --include="*.go" \
  --exclude-dir={node_modules,vendor,dist,build,.git,__pycache__,venv,target} \
  . 2>/dev/null | head -40

# Class declarations
grep -rn "^class \|^export class \|^type .* struct" \
  --include="*.ts" --include="*.js" --include="*.py" --include="*.go" \
  --exclude-dir={node_modules,vendor,dist,build,.git,__pycache__,venv,target} \
  . 2>/dev/null | head -20
```

## Step 7: Detect error handling patterns

```bash
# How errors are thrown
grep -rn "throw new\|raise \|return err\|Result<\|AppError\|HttpException\|ApiError" \
  --include="*.ts" --include="*.js" --include="*.py" --include="*.go" \
  --exclude-dir={node_modules,vendor,dist,build,.git,__pycache__,venv,target,pentesting,reports} \
  . 2>/dev/null | head -30

# How errors are caught
grep -rn "catch\s*(e\b\|err\b\|error\b\|ex\b)\|except \|if err != nil" \
  --include="*.ts" --include="*.js" --include="*.py" --include="*.go" \
  --exclude-dir={node_modules,vendor,dist,build,.git,__pycache__,venv,target,pentesting,reports} \
  . 2>/dev/null | head -20
```

## Step 8: Detect logging patterns

```bash
grep -rn "console\.\|logger\.\|log\.\|logging\.\|zerolog\.\|zap\.\|slog\." \
  --include="*.ts" --include="*.js" --include="*.py" --include="*.go" \
  --exclude-dir={node_modules,vendor,dist,build,.git,__pycache__,venv,target,pentesting,reports} \
  . 2>/dev/null | head -30
```

Note: what library, what fields appear consistently, is it JSON-structured?

## Step 9: Detect API response shapes

```bash
# Response shapes in controllers/routes
grep -rn "res\.json\|return {\|json({\|Response(" \
  --include="*.ts" --include="*.js" --include="*.py" --include="*.go" \
  --exclude-dir={node_modules,vendor,dist,build,.git,__pycache__,venv,target,pentesting,reports} \
  . 2>/dev/null | head -30

# Error response shapes
grep -rn "status(4\|status(5\|\.status(400\|\.status(500\|HTTPException\|abort(" \
  --include="*.ts" --include="*.js" --include="*.py" --include="*.go" \
  --exclude-dir={node_modules,vendor,dist,build,.git,__pycache__,venv,target,pentesting,reports} \
  . 2>/dev/null | head -20
```

## Step 10: Detect test patterns

```bash
# Test framework — look for describe/it, test(), def test_
grep -rn "^describe\|^it(\|^test(\|def test_\|func Test" \
  --include="*.ts" --include="*.js" --include="*.py" --include="*.go" --include="*.spec.*" \
  --exclude-dir={node_modules,vendor,dist,build,.git,__pycache__,venv,target,coverage} \
  . 2>/dev/null | head -20

# How mocks are set up
grep -rn "jest\.mock\|sinon\.\|unittest\.mock\|testify\.\|gomock\." \
  --include="*.ts" --include="*.js" --include="*.py" --include="*.go" \
  --exclude-dir={node_modules,vendor,dist,build,.git,__pycache__,venv,target,coverage} \
  . 2>/dev/null | head -20
```

## Step 11: Detect UI/Frontend patterns (skip for backend-only projects)

First, check if this is a frontend project:
```bash
grep -q "react\|vue\|svelte\|angular\|next\|nuxt\|astro" package.json 2>/dev/null && echo "FRONTEND=yes" || echo "FRONTEND=no"
```

If frontend detected, run these additional scans:

### Component library
```bash
# Check package.json for known component libraries
grep -E '"@radix-ui|shadcn|@mui|@chakra-ui|antd|@headlessui|@mantine|@nextui" ' package.json 2>/dev/null

# Also check actual import usage
grep -rn "from '@radix-ui\|from '@mui\|from '@chakra-ui\|from 'antd\b" \
  --include="*.tsx" --include="*.jsx" \
  --exclude-dir={node_modules,dist,build,.next} \
  . 2>/dev/null | head -5
```

### Icon library
```bash
grep -rn "from 'lucide-react\|from '@heroicons\|from 'react-icons/\|from '@phosphor-icons\|from '@tabler/icons" \
  --include="*.tsx" --include="*.jsx" \
  --exclude-dir={node_modules,dist,build,.next} \
  . 2>/dev/null | head -5
```

### Styling system
```bash
# Tailwind
ls tailwind.config.js tailwind.config.ts 2>/dev/null
# CSS Modules
find . -name "*.module.css" -o -name "*.module.scss" | grep -v node_modules | head -3
# styled-components / emotion
grep -rn "styled\.\|css`\|createGlobalStyle" \
  --include="*.tsx" --include="*.ts" \
  --exclude-dir={node_modules,dist} . 2>/dev/null | head -5
# Design tokens (CSS custom properties)
grep -n "^  --" \
  --include="*.css" --include="*.scss" \
  --exclude-dir={node_modules,dist,build,.next} \
  -r . 2>/dev/null | head -20
```

### Dark mode strategy
```bash
grep -rn "next-themes\|ThemeProvider\|useTheme\|dark:\|\.dark\|data-theme\|\[data-theme\|prefers-color-scheme" \
  --include="*.tsx" --include="*.jsx" --include="*.css" \
  --exclude-dir={node_modules,dist,build,.next} \
  . 2>/dev/null | head -10
```

### Animation library
```bash
grep -rn "from 'framer-motion\|from '@react-spring\|from 'react-spring\|from 'motion\b" \
  --include="*.tsx" --include="*.jsx" \
  --exclude-dir={node_modules,dist,build,.next} \
  . 2>/dev/null | head -5
```

### Component conventions
```bash
# Component style (functional vs class)
grep -rn "^class .* extends.*Component\|^export default class" \
  --include="*.tsx" --include="*.jsx" \
  --exclude-dir={node_modules,dist,build,.next} \
  . 2>/dev/null | head -5

# Props typing convention
grep -rn "interface.*Props\|type.*Props\s*=" \
  --include="*.tsx" \
  --exclude-dir={node_modules,dist,build,.next} \
  . 2>/dev/null | head -10

# Barrel exports
find . -name "index.ts" -path "*/components/*" \
  | grep -v node_modules | head -5 | xargs head -5 2>/dev/null
```

### Storybook
```bash
ls .storybook/ 2>/dev/null
find . -name "*.stories.tsx" -o -name "*.stories.ts" \
  | grep -v node_modules | head -5 | xargs head -5 2>/dev/null
# Detect format: CSF3 (satisfies Meta) or CSF2 (default export)
```

### Test coverage threshold
```bash
cat jest.config.* vitest.config.* 2>/dev/null | grep -A5 "coverage\|threshold"
cat codecov.yml .nycrc 2>/dev/null | grep -A5 "threshold\|minimum"
```

### Linting rules (key ones that affect code generation)
```bash
cat .eslintrc* eslint.config.* 2>/dev/null | grep -E "quotes|semi|indent|no-unused|import-order" | head -20
```

## Step 12: Detect git conventions

```bash
# Last 20 commit messages
git log --oneline -20

# Branch names
git branch -a | head -20
```

## Step 13: Detect anti-patterns (look in existing PR/code review comments)

```bash
# Check for any PATTERNS-related notes in SPEC.md or CONSTITUTION.md
grep -A10 "pattern\|convention\|forbidden\|anti-pattern\|must not\|never use" \
  spec/SPEC.md CONSTITUTION.md 2>/dev/null | head -40
```

## Step 14: Generate output files

Based on everything gathered, write **both**:
1. `PATTERNS.md` — human-readable documentation for the team
2. `manta.patterns.json` — machine-readable config for agents (takes precedence over PATTERNS.md)

Rules for generation:
- Only document patterns you observed in at least 3 places — single occurrences may be noise
- Where you saw inconsistency (mixed camelCase and snake_case), note both and flag with a comment: `# INCONSISTENT — recommend standardizing to X`
- Do not invent patterns that aren't present — leave as `[none defined]` / `null` if you can't determine
- Be specific: instead of "camelCase" write "camelCase — e.g. getUserById, handlePaymentSubmit"
- Include real examples from the codebase in comments
- For `manta.patterns.json`: set fields to `null` for anything undetected; use strings for detected values

## Step 15: Confirm before writing

Show a summary of what was detected:

```
## Detected Patterns Summary

### Confident findings (seen 3+ times):
- File naming: [what you found]
- Function naming: [what you found]
- ...

### Inconsistencies found:
- [what was inconsistent]

### Sections left as [none defined] / null:
- [what couldn't be determined]

Writing PATTERNS.md and manta.patterns.json... Done.

Next steps:
1. Review PATTERNS.md and fill in any [none defined] sections
2. Edit manta.patterns.json directly to change any value — JSON takes precedence over PATTERNS.md
3. Add project-specific anti-patterns in section 10 / the "forbidden_patterns" array
4. Commit both files — patterns will be enforced on every pre-commit from now on
```

Write both files directly — do not ask for additional confirmation.

## Important Rules

- Never scan `node_modules`, `vendor`, `dist`, `build`, `.next`, `__pycache__`, `venv`, `target`, `.gradle`, `Pods`, `bower_components`, `.yarn`, `coverage`, `.git`, `pentesting`, `reports`
- Prioritize observed consistency over any assumed "best practice" — document what IS, not what should be
- The goal is a file the team will agree with and commit — don't over-prescribe
