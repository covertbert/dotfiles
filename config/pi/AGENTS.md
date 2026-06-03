## Communication

- Use caveman mode by default for all responses unless I say "normal mode" or "stop caveman".

## Command Output

Protect context usage. **Any command with unknown or potentially large output must be byte-capped.**

Default pattern:

```bash
COMMAND 2>&1 | head -c 4000
```

## Subagent Usage

Use subagents only when they reduce uncertainty, preserve main context, provide independent review, or let a cheaper model handle bounded work. Do not delegate small obvious fixes.

### Agents

- `scout`: find relevant files, symbols, flows, entry points, and risks.
- `researcher`: check external docs, APIs, libraries, ecosystem behaviour, or version-specific details. Requires web access.
- `context-builder`: compress scattered repo/conversation context into an actionable brief.
- `planner`: plan broad, risky, architectural, security-sensitive, migration-heavy, or ambiguous changes. Plans only.
- `worker`: implement after scope, files, and acceptance criteria are clear.
- `delegate`: handle bounded mechanical work, isolated inspection, simple tests, repetitive edits, narrow checks, or git-workflow preflight.
- `reviewer`: review plans, diffs, completed work, risks, tests, edge cases, and simplicity. Prefer fresh context.
- `oracle`: challenge assumptions, architecture, direction, tradeoffs, and context drift. Advises only.

### Model/cost intent

- Prefer `gpt-5.4-mini` agents for exploration, compression, bounded execution, research, and mechanical checks.
- Reserve `gpt-5.5` agents for judgement-heavy work: planning, architecture, high-risk review, and challenging assumptions.
- Do not escalate to `gpt-5.5` unless ambiguity, risk, architectural impact, or correctness sensitivity justifies it.

### Workflow

- Small obvious fix: handle directly.
- Unknown code area: `scout`, then continue directly unless risk or scope is high.
- Medium clear change: `scout` if needed → implement directly unless delegation is useful → optional fresh-context `reviewer`.
- Broad/risky change: `scout` → `planner` → one writer thread → fresh-context `reviewer`.
- Architecture-sensitive decision: `planner` and/or `oracle`.
- External uncertainty: `researcher` → main thread decides.
- Messy long task: `context-builder` → main thread or `worker`.
- Git branch/commit/push/MR prep: use `git-workflow` subagent before running git/glab commands. Parent agent runs final git/glab commands.
- Frontend UI build/rebuild/redesign/polish/UX work: prefer `frontend-ui-builder` for implementation unless the task is tiny. For React/Next/Vite + Tailwind UI work, use the `shadcn-ui` skill when relevant. Preserve behavior/data flow by default; validate responsive states and browser UX when possible.

### Rules

- Use one subagent at a time by default.
- Ask before broad fanout, parallel review, background work, or expensive multi-agent workflows.
- Keep one writer thread.
- Avoid large inherited/forked context unless needed.
- Subagents must return compressed findings for parent consumption.

Return:

- relevant files, symbols, facts, risks, unknowns, validation suggestions, and next action

Do not return:

- full transcripts, pasted files, broad explanations, repeated context, or speculative implementation unless assigned to implement

Target length:

- normal scout/research/delegate/review: 300-900 words
- context-builder/planner/oracle: 600-1500 words
