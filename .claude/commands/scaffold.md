**Begin by outputting:** `[ Manta — Scaffold ]`

Generate a new feature's files in the project's existing conventions — the structure, wiring and tests a similar feature already has — and leave every business decision the request does not settle as a `TODO` that states the decision. `/write` goes further: it decides those, and adds enterprise defaults the project may not have yet.

## Usage

```
/scaffold "add a user notifications endpoint"
/scaffold "create a password reset flow"
/scaffold "add a background job that sends weekly digest emails"
/scaffold "add a rate limiting middleware"
/scaffold --dry-run "invoice export endpoint"   ← the plan only; nothing written
```

## Instructions

### Step 1: Parse the feature description

The argument is the feature description. If no argument was provided, ask:
```
What feature would you like to scaffold? Describe it in plain English.
Usage: /scaffold "description" [--dry-run]
```
With nobody to answer (`claude -p`, CI) that is the whole output: there is no
default feature to scaffold.

### Step 2: Run scaffolding-agent

Invoke the scaffolding-agent with the feature description.

The agent will:
1. Detect the project stack (package manager, framework, language)
2. Find the single most similar existing feature as a pattern donor
3. Read the pattern donor + its test — nothing more
4. Check spec/SPEC.md alignment (if it exists)
5. Infer all conventions (naming, structure, error handling, response shapes, auth patterns)
6. Present a scaffolding plan (list of files to create)
7. Generate all files

The agent runs as a sub-agent: it cannot stop and wait for an answer, so tell it
so in the prompt. Running `/scaffold "…"` is the request to write; with
`--dry-run`, tell the agent to present the plan and write nothing. Also tell it:

- Write what the pattern donor shows in full — routing, validation,
  persistence calls, the test structure. Leave each business rule the request
  does not settle as a `TODO` that states the decision needed (`// TODO: may a
  paid invoice be exported? (spec §4 is silent)`) — never invent one. That is
  the difference from `/write`.
- Never overwrite an existing file. Edit existing files only to wire the new
  feature in (register a route, export a module), and list any file it would
  have replaced under **Left for you**.

### Output

The scaffolding-agent writes code files directly to the project. No report is generated — the output is the code itself.

After scaffolding, the agent will list:
- All files created
- Spec alignment status
- Next steps (run review, register route, run migration, etc.)

### Running a review after scaffolding

After scaffold completes, run a review on the generated files:
```
/review
```
Or stage and commit to trigger the pre-commit review automatically.

## What scaffolding is NOT

- Not a code generator that ignores your conventions — it mirrors what already exists
- Not a decision-maker — the plumbing is written; the business rules the request leaves open are `TODO`s that say what has to be decided
- Not a replacement for the spec — if the feature isn't in spec/SPEC.md, the agent will flag it
