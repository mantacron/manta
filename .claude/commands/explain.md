**Begin by outputting:** `[ Manta — Explain ]`

Get a plain-language explanation of what a file, function, module, or concept does — including its callers, dependencies, and role in the architecture.

## Usage

```
/project:explain src/auth/jwt.ts
/project:explain "how does the payment flow work?"
/project:explain UserService
/project:explain src/modules/billing/
```

## Instructions

### Step 1: Identify the target

Parse the argument:
- **File path** — a specific file (`src/auth/jwt.ts`, `lib/db/connection.go`)
- **Function or class name** — a symbol (`UserService`, `validateToken`, `PaymentRepository`)
- **Directory** — a module or feature area (`src/modules/billing/`, `pkg/auth/`)
- **Free-text question** — a flow or concept (`"how does the payment flow work?"`, `"what handles authentication?"`)

If no argument was provided, ask:
```
What would you like explained? You can provide:
  - A file path (src/auth/jwt.ts)
  - A function or class name (UserService, validateToken)
  - A directory (src/modules/billing/)
  - A question ("how does the payment flow work?")
```

### Step 2: Locate the code

```bash
# For a file path — read it directly
# For a symbol name — find it:
grep -rn "class [Name]\|function [name]\|def [name]\|func [name]\|const [name]\|export.*[name]" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" --include="*.go" --include="*.rs" \
  . 2>/dev/null | grep -v "node_modules\|dist\|build\|.git\|test\|spec" | head -10

# Find callers (what uses this?)
grep -rn "[Name]\|[name]" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" --include="*.go" \
  . 2>/dev/null | grep -v "node_modules\|dist\|build\|.git" | grep -v "definition file" | head -20

# Check spec for context
grep -A5 "[name]\|[Name]" spec/SPEC.md 2>/dev/null | head -20
```

Read the target file(s) fully. For a directory, read the index/entry file plus up to 3 key files.

### Step 3: Trace the execution path

For functions and endpoints, trace:
1. **Entry point** — where does execution start? (route, event, CLI command, cron job)
2. **Through the layers** — controller → service → repository → DB (or whatever pattern applies)
3. **Side effects** — what does it write, emit, or call externally?
4. **Exit points** — what does it return or respond with?
5. **Error paths** — what can go wrong and how is it handled?

### Step 4: Output the explanation

Structure the explanation for the context:

**For a file:**
```
## [filename]

**What it does**: [1-2 sentence summary]

**Role in the architecture**: [where it sits in the module hierarchy]

**Key exports**:
- `[export name]` — [what it does]
- ...

**Dependencies**:
- Imports from: [list of internal modules it depends on]
- Callers: [list of files that import/use it]

**How it works** (main logic flow):
[Step-by-step narrative of the important paths]

**Edge cases / gotchas**:
[Any non-obvious behavior, invariants, or known limitations]
```

**For a function/class:**
```
## [FunctionName / ClassName]

**Location**: [file:line]

**What it does**: [1-2 sentence summary]

**Called by**: [N callers — list top 3-5]
**Calls into**: [what it delegates to]

**Parameters**:
- `[param]` — [type and purpose]

**Returns**: [what it returns and when]

**Execution flow**:
1. [step]
2. [step]
...

**Error handling**: [what throws and what's caught]

**Things to know**: [gotchas, assumptions, invariants]
```

**For a flow/concept question:**
Answer in plain prose with a numbered walkthrough. Link file:line references where helpful.

### Step 5: Offer follow-up

After the explanation, offer:
> "Want me to explain any of the dependencies in detail? Or show you where to add [related new functionality]?"

## Rules

- Read-only — never modify files
- Calibrate depth to what was asked: a file overview stays high-level; a specific function goes deep
- Always anchor abstract explanations to specific file:line references
- If the target doesn't exist, say so clearly and suggest what to search for instead
- Do not reproduce entire file contents — summarize and excerpt the important parts
- If `spec/SPEC.md` has relevant context, surface it alongside the code explanation
