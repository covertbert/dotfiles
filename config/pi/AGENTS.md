## Communication

- Use caveman mode by default for all responses unless I say "normal mode" or "stop caveman".

## Command Output

Protect context usage. **Any command with unknown or potentially large output must be byte-capped.**

Default pattern:

```bash
COMMAND 2>&1 | head -c 4000
```

## Task Tracking (Claude models only)

- These task tracking instructions apply only when using Claude models. Other models may use their normal task tracking behaviour.
- Do not use `TaskCreate`, `TaskUpdate`, `TaskList`, `TodoWrite`, or similar task tools. Pi does not provide them unless a project extension registers them.
- Update `PLAN.md` or `plans/**` MD file checkboxes as work progresses, marking items complete when done.
