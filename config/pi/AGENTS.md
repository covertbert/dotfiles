## Communication

- Use caveman mode by default for all responses unless I say "normal mode" or "stop caveman".

## Command Output

Protect context usage. **Any command with unknown or potentially large output must be byte-capped.**

Default pattern:

```bash
COMMAND 2>&1 | head -c 4000
```

## Git Workflow

For branch creation, commits, pushes, or merge requests, load and follow the `git-workflow` skill.

- Run required read-only git preflight directly.
- Use byte-capped diff/log commands.
- Propose branch names, Conventional Commit messages, push commands, and MR descriptions from current repo state.
- Run final git/glab commands only after user intent is clear.

## Workflow

- Small obvious fix: handle directly.
- Unknown code area: inspect files and symbols first, then continue directly unless risk or scope is high.
- Medium clear change: inspect relevant code, implement directly, validate.
- Broad/risky change: build a short plan first, then implement in one writer thread.
- Architecture-sensitive decision: pause and explain tradeoffs before editing.
- External uncertainty: check docs/APIs before deciding.
- Git branch/commit/push/MR prep: use `git-workflow` skill.
- Frontend UI build/rebuild/redesign/polish/UX work: load the `frontend-create` skill for distinctive, non-generic visual design. Preserve behavior/data flow by default. Use the `shadcn-ui` skill only when the project already uses shadcn/ui or the user asks for it. Validate responsive states and browser UX when possible.

## Rules

- Ask before broad fanout, background work, or expensive workflows.
- Keep one writer thread.
- Return relevant files, symbols, facts, risks, unknowns, validation suggestions, and next action.
- Do not return full transcripts, pasted files, broad explanations, repeated context, or speculative implementation unless assigned to implement.
