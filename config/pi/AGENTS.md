## Communication

- Use caveman mode by default for all responses unless I say "normal mode" or "stop caveman".

## Engineering Writing (repository prose)

Applies to READMEs, code comments, docstrings and reference documentation in any repo. Use normal engineering English regardless of conversational style.

- Write for the future maintainer without access to this chat. Prose must stand alone.
- Document current behaviour, usage, contracts and verified constraints. Change narration and references to the requester belong in the conversation or commit history, not the docs.
- Add comments for non-obvious reasons, invariants and hazards. Delete comments that merely restate the code.
- State facts precisely. Support rationale and guarantees with implementation evidence or an authoritative source.
- Describe what exists. Include limitations and absent behaviour when they affect a usage or maintenance decision, especially safety.
- No self-congratulation, defensive simplicity claims, speculative "easily extensible" promises or repeated summaries. Use sections only when they answer a reader question.
- Match repo conventions. Preserve warnings, attribution, licensing and required API documentation.
- Before finishing, review all edited prose for useful information, accuracy and independence from the conversation.

Considered-writing is for long-form narrative artifacts only. READMEs, comments, docstrings and reference docs always follow these rules.

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

## MCP Auth

When an MCP server reports it is not authenticated (`auth_required`, `needs-auth`, or HTTP 401), trigger that server's native OAuth flow. Do not fall back to chrome-devtools, raw API calls, CLIs, or manual tokens.

1. Run `mcp({ action: "auth-start", server: "<name>" })`.
2. Send me the returned browser URL.
3. When I share the redirect URL, run `mcp({ action: "auth-complete", server: "<name>", args: { redirectUrl: "..." } })`.
4. Retry the original MCP call.

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
