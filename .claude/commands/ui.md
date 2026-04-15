---
description: Convert design files (screenshots, Figma exports, wireframes) into production-ready UI components matching the project's conventions. Reads from ui-designs/ by default. Enforces DRY by detecting existing components to reuse. Generates responsive, accessible, typed components with tests and optional Storybook stories.
---

**Begin by outputting:** `[ Manta — UI/UX ]`

You are orchestrating the `ui-ux-agent` to convert design inputs into production-ready components.

## Usage

```
/project:ui                              ← scan ui-designs/ and process all unimplemented designs
/project:ui "component description"      ← describe a component, optionally with an image attached
/project:ui ui-designs/checkout.png      ← process a specific design file
/project:ui --dry-run                    ← preview what would be generated (no files written)
/project:ui --dry-run "description"      ← preview for a specific description without writing
/project:ui --update ComponentName       ← update an existing component to match a new design
/project:ui --audit                      ← scan existing components for DRY violations and inconsistencies
```

---

## Step 1: Resolve the Input

### If a path argument was given (e.g. `ui-designs/checkout.png`):
Read the specified file. If it's an image, attach it to the context for visual analysis.

### If `--dry-run` was passed:
Set a flag `DRY_RUN=true`. Continue with normal processing (Steps 2–4) but the ui-ux-agent must **not write any files**. Instead it outputs:
- A summary of what would be generated: file names, component names, states to implement
- Which existing components would be reused
- Which new components would be created
- Approximate lines of code

End with: `> Run without --dry-run to generate these files.`

### If `--update ComponentName` was passed:
1. Search for the existing component:
   ```bash
   find . \( -name "ComponentName.tsx" -o -name "ComponentName.jsx" -o -name "ComponentName.vue" \) \
     | grep -v node_modules | grep -v dist
   ```
2. Read the existing component file.
3. Proceed to Step 2 (DRY pre-check is skipped — we already know the target).
4. Pass the existing component source to ui-ux-agent with instruction: "Update this component to match the new design. Preserve the existing props API where possible — add new props, don't remove them. If the API must break, flag it clearly."

### If `--audit` was passed:
Skip to the DRY audit section below.

### If no argument was given:
Scan the `ui-designs/` directory for design files:

```bash
ls ui-designs/ 2>/dev/null
find ui-designs/ -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \
  -o -name "*.svg" -o -name "*.webp" -o -name "*.pdf" \
  -o -name "*.md" -o -name "*.txt" \) 2>/dev/null | sort
```

If `ui-designs/` doesn't exist:
> "No `ui-designs/` folder found. You can:
> - Create `ui-designs/` and drop your design files there, then re-run `/project:ui`
> - Attach an image directly to this message and describe the component
> - Pass a description: `/project:ui 'a notification toast with icon and dismiss button'`"

Wait for the user to respond.

If `ui-designs/` exists but is empty:
> "The `ui-designs/` folder exists but is empty. Drop design files there (PNG, JPG, SVG, Figma exports) and re-run, or attach an image here."

If design files are found, list them and ask which to process:
> "Found N design file(s) in ui-designs/:
> 1. [filename] — [size or last modified]
> 2. ...
>
> Process all of them? [Y/n] — or enter numbers to select specific files."

---

## Step 2: DRY Pre-Check — Detect What Already Exists

Before generating anything, search for existing components that might already implement (or partially implement) the requested design:

```bash
# Search by component type keywords from the design
grep -rn "component-keyword" \
  --include="*.tsx" --include="*.jsx" --include="*.vue" --include="*.svelte" \
  --exclude-dir={node_modules,dist,build,.next,coverage} \
  src/ components/ app/ 2>/dev/null | head -20

# Also search for similar prop shapes
grep -rn "interface.*Props\|type.*Props" \
  --include="*.tsx" --include="*.ts" \
  --exclude-dir={node_modules,dist,build,.next,coverage} \
  src/ 2>/dev/null | head -20
```

If a similar component is found:
> "⚠ Found an existing `[ComponentName]` at `[path]` that looks similar to what you're building.
> Options:
> (a) **Extend** the existing component — add the new variant/state via props
> (b) **Replace** — the existing one is wrong or too limited
> (c) **Create new** — they're different enough to be separate
>
> Which? [a/b/c]"

Wait for answer. This prevents duplication.

---

## Step 3: Load Design Context

For each design file to process:

1. **Read the image** (Claude reads PNG/JPG/SVG natively)
2. **Check for a companion spec file** — if `checkout.png` exists, look for `checkout.md` or `checkout.txt` in the same folder for written annotations:
   ```bash
   ls ui-designs/ | grep -i "[design-basename]"
   ```
3. **Check if there's a design tokens file**:
   ```bash
   find . -name "tokens.json" -o -name "design-tokens.*" -o -name "theme.*" \
     | grep -v node_modules | head -5
   cat tailwind.config.* 2>/dev/null | grep -A20 "colors\|spacing\|fontSize"
   ```

---

## Step 4: Invoke the ui-ux-agent

Pass all context to the `ui-ux-agent`:
- The image(s) or description
- Design tokens detected
- Similar existing components found
- Project conventions (PATTERNS.md / manta.patterns.json)
- Any companion spec notes

The agent handles the full generation. Refer to `.claude/agents/ui-ux-agent.md` for the complete process.

**Key requirements the agent MUST enforce:**

### Responsiveness (mandatory)
Every component must handle:
- Mobile (< 640px): stacked layout, full-width elements, touch-friendly tap targets (min 44×44px)
- Tablet (640–1024px): condensed layout
- Desktop (> 1024px): full layout as designed

Use the project's responsive system (Tailwind breakpoints, CSS media queries, etc.). Never hardcode pixel widths — use relative units or design system breakpoints.

### DRY enforcement (mandatory)
Before generating any sub-element (button, avatar, badge, input, icon), check if it already exists:
```bash
find . -name "Button.*" -o -name "Avatar.*" -o -name "Badge.*" \
  -o -name "Input.*" -o -name "Icon.*" 2>/dev/null \
  | grep -v node_modules | grep -v dist | head -10
```

**If it exists: import and reuse it.** Never re-implement an existing component. If the existing component is missing a needed variant, extend it via props — don't fork it.

### Pattern compliance (mandatory)
Read and apply:
1. `manta.patterns.json` — `component_style`, `styling`, `props_typing`, `component_size_limit`
2. `PATTERNS.md` section 8 — Component/UI patterns
3. Donor component — match its structure exactly

### Accessibility (mandatory)
- Semantic HTML (not div-soup)
- All interactive elements keyboard-accessible
- ARIA labels on icon-only elements
- Color contrast ≥ 4.5:1 (WCAG AA)
- Reduced-motion support for animations: `@media (prefers-reduced-motion: reduce)`

---

## Step 5: Multiple Designs Workflow

If processing multiple design files, handle them sequentially:

```
Processing 3 design files from ui-designs/

[1/3] checkout-form.png
  → Detected: form with 4 inputs, a summary card, and a submit button
  → Existing components to reuse: Input, Button, Card (all found)
  → Generating: CheckoutForm.tsx (wrapper only — all sub-components already exist)
  ✓ Done

[2/3] notification-toast.png
  → Detected: toast with icon, message, and dismiss button
  → Existing components to reuse: Button (dismiss), Icon (found)
  → New: Toast.tsx, Toast.stories.tsx, Toast.test.tsx
  ✓ Done

[3/3] user-profile-header.png
  → Detected: hero section with avatar, name, role, stats grid
  → Existing components to reuse: Avatar (found), Badge (found)
  → New: ProfileHeader.tsx, ProfileHeader.stories.tsx, ProfileHeader.test.tsx
  ✓ Done

Summary
──────────────────────────────────────────────────────
Files created: 8
Components reused: 5 (Input, Button, Card, Icon, Avatar, Badge)
New components: 3 (CheckoutForm, Toast, ProfileHeader)
Accessibility: all pass
Responsive: ✓ mobile breakpoints added to all
──────────────────────────────────────────────────────
Run /project:review to validate all generated code.
```

---

## Step 6: DRY Audit Mode (`--audit`)

When called with `--audit`:

Scan the component library for duplication and inconsistency:

```bash
# Find components with similar names or props
find . \( -path "*/components/*.tsx" -o -path "*/components/*.jsx" \) \
  | grep -v node_modules | grep -v dist | sort

# Find duplicate prop pattern (e.g. multiple button-like components)
grep -rn "onClick.*handler\|variant.*primary\|size.*sm.*md.*lg" \
  --include="*.tsx" --include="*.jsx" \
  --exclude-dir={node_modules,dist,build} \
  src/ 2>/dev/null | head -30
```

Report:
```
## UI DRY Audit

### Potential Duplicates
- Button.tsx + IconButton.tsx + LinkButton.tsx — 3 button variants, could be unified
- Card.tsx + Panel.tsx + Box.tsx — similar wrapper components

### Inconsistencies
- 3 different loading spinner implementations found
- 2 modal implementations: Modal.tsx and Dialog.tsx

### Recommendations
1. Unify button variants into Button.tsx with `variant` and `as` props
2. Remove Panel.tsx — it's Card.tsx with different padding
3. Consolidate spinners into a single Spinner.tsx
```

---

## Important Rules

- **Never generate a component that already exists** — extend it instead
- **Never use arbitrary px values** when design tokens or Tailwind utilities exist
- **Never generate non-responsive components** — mobile-first is mandatory
- **Never skip accessibility** — ARIA and keyboard nav are not optional
- **Always check for existing components before generating** — DRY is enforced at orchestrator level
- **`ui-designs/` is the convention** — suggest creating it if it doesn't exist
