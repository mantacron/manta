# PATTERNS.md — Project Coding Patterns

> **How this file works**: Each section below defines the conventions this project has adopted.
> Fill in the patterns that apply. Leave sections as `[none defined]` if they are open.
>
> This file is read by:
> - `code-quality` agent at pre-commit — violations become WARNING findings
> - `scaffolding-agent` — generates code that matches these patterns automatically
>
> Run `/project:capture-patterns` to auto-populate this file from your existing codebase.
> Commit this file alongside your source code so the whole team enforces the same conventions.

---

## 1. Naming Conventions

### 1.1 Files
```
# Format: <pattern> → <description>
# Examples:
#   kebab-case    → user-profile.ts, get-users.service.ts
#   PascalCase    → UserProfile.tsx, UserService.ts
#   snake_case    → user_profile.py, get_users.py

source_files: [none defined]
test_files: [none defined]
migration_files: [none defined]
config_files: [none defined]
```

### 1.2 Functions / Methods
```
# Examples:
#   camelCase     → getUser(), handleSubmit()
#   snake_case    → get_user(), handle_submit()
#   PascalCase    → GetUser(), HandleSubmit()  (Go)

style: [none defined]
async_prefix: [none defined]   # e.g. "async" suffix, or just camelCase
handler_prefix: [none defined] # e.g. "handle" for event handlers
getter_prefix: [none defined]  # e.g. "get" / "fetch" / none
```

### 1.3 Classes / Types / Interfaces
```
style: [none defined]          # typically PascalCase
interface_prefix: [none defined]  # e.g. "I" prefix (IUserService) or none
type_suffix: [none defined]    # e.g. "Type" suffix or none
dto_suffix: [none defined]     # e.g. "Dto" / "DTO" / "Request" / "Response"
```

### 1.4 Constants / Enums
```
style: [none defined]          # e.g. SCREAMING_SNAKE_CASE, PascalCase for enums
enum_values: [none defined]    # e.g. SCREAMING_SNAKE_CASE, PascalCase
```

### 1.5 Database Tables and Columns
```
table_style: [none defined]    # e.g. snake_case plural (users, user_roles)
column_style: [none defined]   # e.g. snake_case (created_at, user_id)
primary_key: [none defined]    # e.g. "id" UUID / auto-increment integer
foreign_key: [none defined]    # e.g. "<table_singular>_id" (user_id, post_id)
timestamp_columns: [none defined]  # e.g. created_at, updated_at, deleted_at
```

---

## 2. Folder Structure

```
# Describe your project's folder layout here.
# Example for a TypeScript API:
#
# src/
#   controllers/   ← HTTP layer only, no business logic
#   services/      ← all business logic
#   repositories/  ← database access only
#   models/        ← data types / entities
#   middleware/    ← Express/Fastify middleware
#   utils/         ← pure utility functions (no I/O)
#   config/        ← environment + app config
#   types/         ← shared TypeScript types
# tests/
#   unit/          ← co-located with source
#   integration/   ← test full request path
#   fixtures/      ← shared test data

layout: [none defined]
layer_rules: [none defined]    # e.g. "no database calls in controllers"
```

---

## 3. Import / Module Style

```
# Examples:
#   absolute   → import { UserService } from 'src/services/user.service'
#   relative   → import { UserService } from '../services/user.service'
#   alias      → import { UserService } from '@services/user.service'

import_style: [none defined]
import_order: [none defined]   # e.g. stdlib → third-party → internal → relative
barrel_exports: [none defined] # e.g. "use index.ts re-exports" or "no barrel files"
```

---

## 4. Error Handling

```
# Describe how errors should be thrown, caught, and returned.
# Examples:
#   throw_style: "custom Error subclasses — AppError, ValidationError, NotFoundError"
#   catch_style: "catch at controller boundary only — services throw, never swallow"
#   return_style: "Result<T, E> tuple — never throw in service layer"
#   http_errors: "use HttpException(status, message) — never return raw Error to client"

throw_style: [none defined]
catch_boundary: [none defined]
error_shape: [none defined]    # e.g. { code, message, details }
logging_on_error: [none defined]  # e.g. "log at catch site with context, re-throw"
```

---

## 5. Logging Format

```
# Describe the logging library, levels, and field conventions.
# Examples:
#   library: "winston / pino / structlog / zerolog / zap"
#   format: "structured JSON"
#   levels: "error / warn / info / debug — no trace in production"
#   required_fields: "timestamp, level, service, request_id, user_id (if authed)"
#   forbidden: "no PII in logs — mask email, phone, card numbers"

library: [none defined]
format: [none defined]         # "JSON" or "plaintext"
levels_used: [none defined]
required_fields: [none defined]
forbidden_fields: [none defined]  # e.g. "password, email, card_number, ssn"
request_id: [none defined]     # e.g. "propagate X-Request-ID through all log lines"
```

---

## 6. API Response Shapes

```
# Describe the standard response envelope for REST/GraphQL/gRPC.
# Examples:
#   success:
#     { data: T, meta?: { page, total } }
#   error:
#     { error: { code: string, message: string, details?: object } }
#   paginated:
#     { data: T[], meta: { page: number, perPage: number, total: number } }

success_shape: [none defined]
error_shape: [none defined]
paginated_shape: [none defined]
status_codes: [none defined]   # e.g. "200 OK, 201 Created, 400 Bad Request, 401, 403, 404, 422, 500"
versioning: [none defined]     # e.g. "/api/v1/" URL prefix or "Accept: application/vnd.api+json;version=1"
```

---

## 7. Test Patterns

```
# Describe testing conventions.
# Examples:
#   framework: "Jest / Vitest / pytest / Go testing / RSpec"
#   structure: "describe > it / context > it"
#   naming: "it('should [behavior] when [condition]')"
#   mocking: "mock at module boundary — never mock internal functions"
#   fixtures: "factory functions in tests/fixtures/ — no hardcoded IDs"
#   db_tests: "real database via test container — no in-memory sqlite"
#   coverage_min: "80% line coverage on services/"

framework: [none defined]
file_location: [none defined]  # e.g. "co-located __tests__/" or "top-level tests/"
describe_style: [none defined]
naming_convention: [none defined]
mock_strategy: [none defined]
fixture_strategy: [none defined]
coverage_threshold: [none defined]
```

---

## 8. Component / UI Patterns (Frontend only)

```
# Skip this section for backend-only projects.
# Examples:
#   component_style:     "functional components only — no class components"
#   component_library:   "shadcn/ui — use existing primitives, don't re-implement"
#   styling:             "Tailwind utility classes — no inline styles, no CSS modules"
#   icon_library:        "lucide-react — always import from lucide-react, no inline SVGs"
#   state_management:    "useState for local, Zustand for global — no Redux"
#   props_typing:        "Props interface defined above component in same file"
#   component_size_limit:"max ~150 lines per component — extract sub-components if larger"
#   storybook:           "yes — every shared component needs a story in CSF3 format"
#   dark_mode:           "CSS custom properties via next-themes — never hardcode light colors"
#   animation_library:   "framer-motion — no raw CSS transitions for complex animations"
#   responsive_strategy: "mobile-first Tailwind breakpoints — sm: md: lg: xl:"
#   barrel_exports:      "yes — src/components/index.ts re-exports all public components"

component_style: [none defined]
component_library: [none defined]
styling: [none defined]
icon_library: [none defined]
state_management: [none defined]
props_typing: [none defined]
component_size_limit: [none defined]
storybook: [none defined]
dark_mode: [none defined]
animation_library: [none defined]
responsive_strategy: [none defined]
barrel_exports: [none defined]
```

---

## 9. Commit / Branch Patterns

```
# Describe Git workflow conventions.
# Examples:
#   commit_style: "Conventional Commits — feat:, fix:, chore:, docs:, refactor:"
#   branch_naming: "<type>/<ticket-id>-<short-description> — feat/PROJ-123-user-auth"
#   pr_size: "max ~400 lines changed per PR — split larger changes"
#   squash: "squash merge to main — keep history clean"

commit_style: [none defined]
branch_naming: [none defined]
pr_size_limit: [none defined]
merge_strategy: [none defined]
```

---

## 10. Project-Specific Anti-Patterns

```
# List things that are explicitly FORBIDDEN in this codebase.
# These become CRITICAL findings when detected by code-quality.
# Examples:
#   - "Never use mongoose.connect() outside of src/config/database.ts"
#   - "Never call the payment API directly — always use PaymentService"
#   - "Never store user IDs in localStorage — use session cookies only"
#   - "Never use raw SQL — always use the query builder"

forbidden: [none defined]
```

---

## 11. Performance Conventions

```
# Examples:
#   pagination: "all list endpoints must be paginated — max 100 items per page"
#   caching: "use Redis for anything called >10/sec — TTL required"
#   db_queries: "no N+1 — always use eager loading / JOINs for related data"
#   background_jobs: "anything >100ms goes to a queue"

pagination: [none defined]
caching: [none defined]
db_query_rules: [none defined]
async_threshold: [none defined]
```
