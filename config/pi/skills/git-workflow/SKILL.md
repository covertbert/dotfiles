---
name: git-workflow
description: Use when committing code, creating or updating a pull/merge request, pushing a branch, writing commit messages, or preparing change submissions. Covers conventional commits and MR creation with glab.
---

# Git Workflow

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
