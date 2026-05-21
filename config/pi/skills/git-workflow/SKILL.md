---
name: git-workflow
description: Use when committing code, creating a branch, creating or updating a pull/merge request, pushing a branch, writing commit messages, or preparing change submissions. Covers conventional commits and MR creation with glab.
---

# Git Workflow

## Mandatory preflight — use GPT-5.4 mini subagent first

**Before running any git command for branch creation, commits, push, or MR**, delegate to the `git-workflow` subagent (configured as GPT-5.4 mini with minimal thinking). This is not optional.

| User intent             | GPT-5.4 mini task                                                                                             |
| ----------------------- | ------------------------------------------------------------------------------------------------------------- |
| Create / name a branch  | "Inspect current git state and propose a branch name and checkout command."                                   |
| Commit (stage + commit) | "Inspect git status and staged diff. List files to stage and propose a Conventional Commit message."          |
| Push branch             | "Inspect git status and unpushed commits. Assess push risk and provide the push command."                     |
| Open or update MR       | "Inspect branch commits and diff. Draft a plain-Markdown MR description with intent and scope sections only." |

Use the output as-is or adjust before running. Parent agent (you) makes the final decision and runs all git/glab commands.

Example delegation:

```
Use git-workflow to inspect current git state and propose a branch name.
```

## Commit messages

- Use Conventional Commits: `type(scope): summary`
- Allowed types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`, `build`, `perf`
- Summary: concise, imperative

## Merge Requests

- Always use `glab` CLI to open MRs.
- MR description must describe intent and scope.
- MR descriptions must be plain Markdown with real line breaks.
- Never include escaped newline sequences like `\n` in MR descriptions.
- Never pass multi-line MR descriptions as a quoted string with escaped newline characters.
- For any multi-line MR description, write body to a temp file and use `glab mr create --description-file`.
- Never add a "Validation" heading and associated bullet points to MR description.
