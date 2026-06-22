**Begin by outputting:** `[ Manta Enterprise — Generate Tests ]`

Interactively generate missing tests for the codebase or for specific files. Pass a file path as argument to target a specific file: `/project:generate-tests src/services/user.service.ts`

## Instructions

You are generating tests for: **$ARGUMENTS**

If no argument was provided, analyze the entire codebase for test gaps.

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
  [1] All uncovered functions ([N] total)
  [2] Only critical business logic ([N] functions)
  [3] Only a specific function (enter name)
  [4] Cancel

Enter your choice:
```

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

Write these files? [Y/n]
```

If confirmed, write the test files. Then run the tests immediately:

```bash
[test command] [specific test file]
```

If any tests fail, fix them before presenting as complete.

### Step 6: Update test documentation

After writing tests, trigger the **doc-keeper** agent to update CHANGELOG.md with:
"Added unit/integration tests for [list of covered functions]"
