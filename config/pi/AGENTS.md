## Communication

- Use caveman mode by default for all responses unless I say "normal mode" or "stop caveman".

## Command Output

Protect context usage. **Any command with unknown or potentially large output must be byte-capped.**

Default pattern:

```bash
COMMAND 2>&1 | head -c 4000
```

## Subagent Usage

Proactively use subagents when a task benefits from delegation. Infer the best agent from prompt content:

- Use `scout` for codebase exploration, finding relevant files, and understanding flow.
- Use `researcher` when external docs, current info, APIs, libraries, or ecosystem behavior matter.
- Use `planner` for multi-step, risky, broad, or architecture-sensitive changes before editing.
- Use `worker` for implementation after scope is clear.
- Use `reviewer` for diffs, plans, completed work, risk checks, and validation.
- Use `oracle` when direction, assumptions, architecture, tradeoffs, or context drift need challenge.
- Use `git-workflow` for branch names, commit messages, MR descriptions, and push checks.

Default workflow:

- Small obvious fix: handle directly unless subagents are requested or risk is non-trivial.
- Unknown code area: use `scout` first.
- Non-trivial change: use `scout` → `planner` → ask/confirm when needed → `worker` → `reviewer`.
- Completed diff: use one or more fresh-context `reviewer` passes.
- Ambiguous or risky decision: use `oracle`.

Prefer cheap overridden agents where configured. Keep one writer thread. Ask before broad/costly fanout or irreversible changes.
