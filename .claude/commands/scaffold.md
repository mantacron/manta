**Begin by outputting:** `[ Manta Enterprise — Scaffold ]`

Generate consistent boilerplate for a new feature, matching the project's existing conventions exactly.

## Usage

```
/project:scaffold "add a user notifications endpoint"
/project:scaffold "create a password reset flow"
/project:scaffold "add a background job that sends weekly digest emails"
/project:scaffold "add a rate limiting middleware"
```

## Instructions

### Step 1: Parse the feature description

The argument is the feature description. If no argument was provided, ask:
```
What feature would you like to scaffold? Describe it in plain English.
```

### Step 2: Run scaffolding-agent

Invoke the scaffolding-agent with the feature description.

The agent will:
1. Detect the project stack (package manager, framework, language)
2. Find the single most similar existing feature as a pattern donor
3. Read the pattern donor + its test — nothing more
4. Check spec/SPEC.md alignment (if it exists)
5. Infer all conventions (naming, structure, error handling, response shapes, auth patterns)
6. Present a scaffolding plan (list of files to create) and ask for confirmation
7. Generate all files on confirmation

### Output

The scaffolding-agent writes code files directly to the project. No report is generated — the output is the code itself.

After scaffolding, the agent will list:
- All files created
- Spec alignment status
- Next steps (run review, register route, run migration, etc.)

### Running a review after scaffolding

After scaffold completes, run a review on the generated files:
```
/project:review
```
Or stage and commit to trigger the pre-commit review automatically.

## What scaffolding is NOT

- Not a code generator that ignores your conventions — it mirrors what already exists
- Not a full feature implementation — it generates the skeleton; you fill in the business logic
- Not a replacement for the spec — if the feature isn't in spec/SPEC.md, the agent will flag it
