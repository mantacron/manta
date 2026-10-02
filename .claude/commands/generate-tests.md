**Begin by outputting:** `[ Manta — Generate Tests ]`

Generate missing tests for the codebase or for specific files. Pass a file path as argument to target a specific file: `/generate-tests src/services/user.service.ts`

```
/generate-tests src/billing/proration.ts          ← gaps, then two questions: which, and write?
/generate-tests src/billing/proration.ts --yes    ← the default choice, written without asking
/generate-tests --critical --yes                  ← critical business logic across the codebase
/generate-tests src/x.ts --only applyDiscount     ← one function
/generate-tests src/x.ts --no                     ← gaps and a preview; nothing written
```

## Answering without a person

Two questions: which gaps to cover (Step 2), and whether to write the tests
(Step 5). Each has a default, and the flags answer them up front:

- Which: `--all` (every uncovered function), `--critical` (critical business
  logic only), `--only <name>`. Default: `--all` for a file target, `--critical`
  for the whole codebase.
- Write: `--yes` (or `MANTA_ASSUME=yes` in the environment) writes them and
  takes the default *which* if none was given; `--no` (or `MANTA_ASSUME=no`)
  shows the gaps and a preview and writes nothing.
- With nothing given, ask each question when you reach it, and end it with
  what an unanswered run leaves: `Nothing is written without an answer —
  re-run with --yes to write [the default].` A `claude -p` or CI run stops at
  the first question with the gap analysis on screen.

Check the environment once, at Step 1: `echo "MANTA_ASSUME=${MANTA_ASSUME:-}"`.

## Instructions

You are generating tests for: **$ARGUMENTS** (the file, without the flags)

If no file was named, analyze the entire codebase for test gaps.

### Step 1: Analyze coverage gaps

If a specific file was provided:
- Read the file completely
- Find the corresponding test file (or note it doesn't exist)
- Map every exported function/class/method to its tests
- Identify what's missing

If no file provided:
- Search for source files without corresponding test files:
```bash
# Find source files
find . -type f \( -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" \) \
  ! -path "*/node_modules/*" ! -path "*/__pycache__/*" ! -path "*/.git/*" \
  ! -name "*.test.*" ! -name "*.spec.*" ! -name "*_test.*" | head -50

# Find test files
find . -type f \( -name "*.test.*" -o -name "*.spec.*" -o -name "*_test.*" \) \
  ! -path "*/node_modules/*" | head -50
```
- Read up to 10 source files and check for untested exported functions
- Report the most critical coverage gaps

### Step 2: Present coverage gaps

Show the user exactly what's not covered:

```
Coverage Analysis:
═══════════════════════════════════════

[file path]
  Functions without tests:
  ✗ [functionName] — [why it needs tests]
  ✗ [functionName] — [why it needs tests]

  Functions with partial coverage (missing edge cases):
  ⚠ [functionName] — missing: [null input, error path, etc.]

Would you like me to generate tests for:
  [1] All uncovered functions ([N] total)            (--all)
  [2] Only critical business logic ([N] functions)  (--critical)
  [3] Only a specific function (enter name)          (--only <name>)
  [4] Cancel

Enter your choice — default [1] for a file, [2] for the whole codebase:
Nothing is written without an answer — re-run with --yes to cover [the default].
```

Skip the question when `--all`, `--critical`, `--only` or `--yes` answered it.

### Step 3: Detect test framework

Before generating, detect the test framework:

```bash
# Check package.json for test dependencies
cat package.json 2>/dev/null | grep -E '"(jest|vitest|mocha|jasmine|ava|tap)"'

# Check Python
cat requirements*.txt pyproject.toml setup.cfg 2>/dev/null | grep -E '(pytest|unittest|nose)'

# Check Go
# Uses standard testing package

# Check Rust
# Uses standard #[test] attribute

# Check config files
ls jest.config.* vitest.config.* pytest.ini .mocharc.* 2>/dev/null
```

### Step 4: Generate tests

Generate complete, runnable test files. Each test file must:

**Structure**:
- Follow existing test file naming conventions in the project
- Be placed in the correct test directory
- Import from correct relative paths
- Use the detected test framework's syntax exactly

**Content requirements**:
- Each test has a clear, descriptive name: `it('returns 404 when user does not exist')`
- Tests are independent — no shared mutable state
- Setup and teardown are explicit
- Mocks are minimal — only mock I/O, not business logic
- Assertions are specific — check the exact value, not just truthiness
- Test data is realistic — not `"test"` and `1`, but `"john@example.com"` and real-looking values

**Test the behaviour the code is meant to have, not whatever it does today.**
The oracle is the spec, the function's name and docstring, the route's
contract — not the current output. When the current behaviour looks wrong — a
finding in `reports/` names it, the spec says otherwise, or it is plainly a bug
(the same idempotency key accepted for two different payments) — do not write a
test that asserts it: that turns the bug into a requirement, and the next fix
fails the suite. Write the test for the intended behaviour and mark it as an
expected failure (`it.fails`, `@pytest.mark.xfail(reason=…)`, `t.Skip` with
the reason), or leave it out, and list it under **Suspected bugs** in the
output either way. One generated test in a customer session reused a single
request id for three different payments and asserted all three were recorded —
freezing the duplicate-payment bug `/security-scan` had just reported.

**Coverage per function** (at minimum):
1. Happy path — normal input, expected output
2. Edge case: empty/null/undefined input
3. Edge case: boundary values (min, max)
4. Error path: what happens when dependencies fail
5. Authorization: what happens with unauthorized input (if applicable)

**Template for TypeScript/Vitest**:
```typescript
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { [functionName] } from '../[module]'

describe('[functionName]', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('returns [expected] when given [normal input]', async () => {
    // Arrange
    const input = [realistic test value]

    // Act
    const result = await [functionName](input)

    // Assert
    expect(result).toEqual([expected output])
  })

  it('throws [ErrorType] when [edge case]', async () => {
    await expect([functionName](null)).rejects.toThrow('[error message]')
  })
})
```

### Step 5: Confirm and write

Show the generated tests to the user before writing:

```
I'll create [N] test file(s):
- [path/to/test.file] ([N] test cases)

[Preview of generated tests]
Suspected bugs (not asserted as correct): [list, or "none"]

Write these files? [Y/n]
Nothing is written without an answer — re-run with --yes to write them.
```

Skip the question with `--yes`; with `--no`, stop after the preview.

If confirmed, write the test files. Then run the tests immediately:

```bash
[test command] [specific test file]
```

If a test fails, find out whose fault it is before touching it. A mistake in
the test (a wrong import, a wrong fixture) is fixed. A failure that shows the
code does not do what it is meant to is a finding, not a test to weaken: mark
it as an expected failure with the reason and list it under **Suspected bugs**.

This command writes test files and nothing else — not CHANGELOG.md, not the
README. Documentation is `/update-docs`'s job, when the person asks for it.

### Step 6: Next Steps

```
Next steps:
  → git add [test files] && git commit    commit tests before they drift
  → /review                        run a full review now that tests are in place
  → /update-docs                   note the new tests in CHANGELOG/README, if you want them there
```
