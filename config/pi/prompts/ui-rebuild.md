---
description: Rebuild a frontend UI with strong UX using the frontend-ui-builder subagent
argument-hint: "<target UI or instructions>"
---

Use `frontend-ui-builder` to rebuild this UI with strong UX and product-quality execution:

$ARGUMENTS

Default contract:

- Treat this as a rebuild, not a light polish pass, unless I explicitly say otherwise.
- Preserve existing behavior, data flow, API calls, routes, permissions, validation, tests, and public component APIs unless I explicitly approve changing them.
- Use shadcn/ui, Radix primitives, Tailwind, and existing design tokens/components where appropriate.
- Improve information architecture, hierarchy, spacing, typography, responsive layout, states, and accessibility.
- Include loading, empty, error, disabled, success, long-content, and permission/locked states when relevant.
- Validate with available package scripts and browser/user-flow checks when possible.
- Report changed files, behavior preserved/changed, shadcn/ui components used or added, validation commands with exit codes, browser evidence, and remaining risks.
