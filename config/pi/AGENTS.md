## Communication

- Use caveman mode by default for all responses unless I say "normal mode" or "stop caveman".

## Command Output

Protect context usage. **Any command with unknown or potentially large output must be byte-capped.**

Default pattern:

```bash
COMMAND 2>&1 | head -c 4000
```

## Task Tracking

- Do not use `TaskCreate`, `TaskUpdate`, `TaskList`, `TodoWrite`, or similar task tools. Pi does not provide them unless a project extension registers them.
- Track execution progress in `PLAN.md` and final responses using `[DONE:n]` markers.

## Git, commit & Merge Request rules

- Always use Conventional Commits for every commit.
- Format commit messages as: `type(scope): summary`
- Allowed types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`, `build`, `perf`
- Keep the summary concise and imperative.
- Always use the `glab` CLI to open MRs.
- MRs should contain a description that describes intent and scope.
- MR descriptions must be plain Markdown with real line breaks.
- Never include escaped newline sequences like `\n` in MR descriptions.
- Never pass multi-line MR descriptions as a quoted string with escaped newline characters.
- For any multi-line MR description, write the body to a temp file and use `glab mr create --description-file`.
- Never add a "Validation" heading and associated bullet points to MR description.

## PHP/Symfony Repos

- All static checks should be run using the provided Docker compose before task is deemed complete
- If Docker desktop isn't running, stop what you're doing and ask me to run it.
- PHP Unit tests should only be run for files you deem to have changed.

## NPM/Node repos

- Always use nvm + nvmrc for node/npm versions

## Execution Handoff

When I ask for an "execution handoff" please do the following:

Turn the final plan into a compact execution handoff for a cheaper Codex model.

Include:

- goal
- relevant files or areas to inspect
- exact implementation steps
- constraints / things not to change
- acceptance criteria
- test commands to run
- likely risks

Remove:

- exploratory reasoning
- rejected options
- unnecessary background
- uncertainty unless it affects implementation
