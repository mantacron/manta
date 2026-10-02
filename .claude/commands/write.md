**Begin by outputting:** `[ Manta — Write ]`

Write a complete production-ready implementation — enterprise defaults (rate limiting, auth, validation, pagination, transactions, audit trail) baked in. No TODOs, no placeholder logic.

## What This Is

`/write` goes further than `/scaffold`. Scaffold generates a skeleton — you fill in the business logic. Write generates the full implementation: complete controllers, services, repositories, validation, error handling, rate limiting, auth wiring, pagination, tests — ready to ship.

Use `scaffold` when you want to mirror the team's boilerplate. Use `write` when you want production-ready code with enterprise defaults applied.

## Usage

```
/write "add a user notifications endpoint with read/unread tracking"
/write "create a password reset flow with token expiry and rate limiting"
/write "add a POST /payments endpoint with idempotency and audit logging"
/write "add a background job that processes queued email sends with retry"
/write "add a GET /admin/users endpoint with role-based access and pagination"
/write --dry-run "add a POST /payments endpoint"   ← the plan only; nothing written
```

## Instructions

### Step 1: Parse the feature description

The argument is the feature description. If no argument was provided, ask:
```
What feature would you like to write? Describe it in plain English — include any constraints
(auth required, rate limits, data shape, spec reference) and I'll implement it completely.
Usage: /write "description" [--dry-run]
```
With nobody to answer (`claude -p`, CI) that is the whole output: there is no
default feature to write.

### Step 2: Run code-writer agent

Invoke the `code-writer` agent with the full feature description.

The agent will:
1. Load `manta.patterns.json` / `PATTERNS.md` — project conventions are authoritative
2. Detect the stack (framework, ORM, validation library, auth, logger, rate limiter)
3. Find the most similar existing feature as a pattern donor (for conventions)
4. Detect existing infrastructure (auth middleware, error hierarchy, logger, rate limiter)
5. Check `spec/SPEC.md` alignment
6. Present a complete implementation plan (all files, all layers, all enterprise defaults applied)
7. Write every file — no TODOs, no placeholder logic

The agent runs as a sub-agent: it cannot stop and wait for an answer, so tell it
so in the prompt. Running `/write "…"` is the request to write; with
`--dry-run`, tell the agent to present the plan and write nothing. Also tell it
the limits of what it may change on its own:

- **The feature, and what it needs.** A module the enterprise defaults need
  (a rate limiter, an audit logger) may be added — and is listed in the summary
  under **Added beyond the request**.
- **Nothing that changes existing behaviour outside the feature.** Making an
  optional setting required (an env var the app now refuses to start without),
  changing a default, rewriting the README, reshaping an existing response —
  not done; each goes in the summary under **Proposed, not done**, with why.
  On 2026-10-02 `/write` made an upload directory required at import time — the
  app no longer started without it — and rewrote the README, unasked.
- **What the spec rules out stays out.** A non-goal or accepted constraint in
  `spec/SPEC.md` (auth handled by a gateway) is respected, and said.
- **Never overwrite an existing file.** Edit existing files only to wire the
  feature in, and list any file it would have replaced under **Left for you**.

### Step 3: Post-write

After the agent writes the code, run a review to validate it:
```
/review
```

Or stage and commit to trigger the pre-commit hook automatically.

## Enterprise Defaults Applied

The code-writer applies these patterns unless the project already has them (in which case it uses what's there):

| Pattern | What gets generated |
|---|---|
| **Rate limiting** | Per-route limiter — tighter for unauthenticated, looser for authenticated. Returns `429` with `Retry-After`. |
| **Auth middleware** | Wires existing auth middleware for protected routes. Extracts user from token — never from request body. |
| **Input validation** | DTO/schema per endpoint (body, query params, path params). `400` with field-level errors on failure. |
| **Clean controller** | Thin handler — parse input, call service, respond. No DB calls. No business logic. |
| **Service layer** | All business logic. Throws typed domain errors. Wraps multi-step mutations in transactions. |
| **Repository layer** | All DB access. Returns domain objects. Accepts transaction context. |
| **Pagination** | List endpoints: cursor-based or offset per project convention. Max cap on limit. Returns `{ data, meta }`. |
| **Structured errors** | Typed domain errors mapped to HTTP codes. No stack traces in production responses. |
| **Request logging** | Trace ID, method, path, user ID, latency. No PII in logs. |
| **DB transactions** | Multi-table mutations wrapped in a transaction. |
| **Audit trail** | Create/update/delete on sensitive resources logged with actor, action, resource, timestamp. |
| **External call safety** | Timeout set. Timeout/network errors handled. Non-critical calls degrade gracefully. |
| **Migration** | Includes rollback (`DOWN`). Indexes on FK and frequently-queried columns. |

## What Write Is NOT

- Not a spec replacement — if the feature isn't in `spec/SPEC.md`, the agent flags it as a deviation
- Not a one-shot deploy button — run `/review` after writing
- Not a magic wand — complex domain logic still needs your input on the business rules
- Not overwriting existing files — an existing file is edited only to wire the feature in; one it would have replaced is listed for you
- Not a silent refactor — changes to existing behaviour outside the feature are proposed in the summary, not made
