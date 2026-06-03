---
name: shadcn-ui
description: Use when building or rebuilding React/Next/Vite UIs with shadcn/ui, Radix UI, Tailwind CSS, component registries, or the shadcn CLI. Covers component installation, theming, accessibility states, responsive layout, and validation.
---

# shadcn/ui

## Scope

Use this skill when a task mentions shadcn/ui, Radix UI primitives, Tailwind component work, design-system components, or rebuilding/building React UIs with polished product quality.

## First checks

- Detect project stack before editing: `package.json`, lockfile, `.nvmrc`, `components.json`, Tailwind config, app/router structure, existing components, existing tokens.
- Use the repo package manager and Node version. Follow the `node-npm` skill when present.
- If `components.json` is missing, do not blindly initialize shadcn/ui in an established app. Initialize only when the user explicitly requested shadcn/ui setup and the stack is clearly compatible; otherwise ask or report the decision needed.
- Prefer official CLI/docs when behavior is uncertain: `npx shadcn@latest init`, `npx shadcn@latest add ...`, and https://ui.shadcn.com/docs.

## Component workflow

- Add registry components with `npx shadcn@latest add <component>` instead of copying registry source by hand when the CLI works.
- Inspect generated components before modifying them. Preserve local project conventions.
- Prefer shadcn/Radix primitives for dialogs, menus, popovers, tabs, forms, selects, command palettes, toasts, sheets, accordions, and data-entry controls.
- Use existing `cn`/class utilities. Do not create duplicate styling helpers.
- Avoid new dependencies unless needed and already aligned with the project.

## UI implementation rules

- Use semantic Tailwind tokens first: `bg-background`, `text-foreground`, `text-muted-foreground`, `border`, `ring`, `card`, `popover`, `primary`, `secondary`, `destructive`, `accent`, etc.
- Avoid hard-coded color palettes unless the project already uses them intentionally.
- Keep dark mode intact when the app supports it.
- Build complete states: loading, empty, error, disabled, optimistic/success, long-content, and permission/locked states when relevant.
- Design responsive layouts by default. Check small, medium, and large breakpoints.
- Preserve keyboard navigation, visible focus, ARIA semantics, labels, names, descriptions, and error messages.
- Keep motion restrained and purposeful. Respect reduced-motion patterns when existing.
- Split large UI into clear components only when it improves readability or reuse.

## Rebuilding existing UI

- Preserve behavior unless the user explicitly approves changing it: routes, API calls, mutations, forms, validation, permissions, analytics, copy contracts, tests, URL/query params, and state machines.
- Map current data flow and edge states before replacing UI.
- Rebuild layout and presentation boldly when asked. Do not limit work to cosmetic tweaks if the request is a total rebuild.
- Keep public component APIs stable unless the parent task approves breaking changes.

## Greenfield UI

- Derive a compact design brief before writing code: user goal, information architecture, primary actions, hierarchy, states, responsive needs, and likely components.
- Make reasonable product/taste decisions when low-risk. Stop and ask/report when a missing decision changes scope, data model, or behavior.
- Prefer realistic content and useful affordances over placeholder-heavy generic SaaS output.

## Validation

- Run focused checks that exist in `package.json`: lint, typecheck, test, build, or route-specific tests. Do not invent scripts.
- If the app can run locally, validate with a browser or available browser automation. Check desktop and mobile widths, key flows, focus states, and core UI states.
- If browser validation is impossible, report why and provide next-best evidence from static checks and code inspection.
- Report command exit codes and any failures exactly.
