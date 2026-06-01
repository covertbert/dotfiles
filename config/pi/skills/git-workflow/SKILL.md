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

- Prefer `glab mr create` over `git push -o merge_request.create`.
- Do not use git push options for MR descriptions. Push options are safe only for simple single-line metadata.
- Always use `glab` CLI to open MRs.
- MR description must describe intent and scope.
- MR descriptions must be plain Markdown with real line breaks.
- Never include escaped newline sequences like `\n` in MR descriptions.
- Never pass multi-line MR descriptions as a quoted string with escaped newline characters.
- For any multi-line MR description:
  1. write body to temp file
  2. create MR with `glab mr create --description "$(cat "$tmpfile")"`
- Do not assume `glab` supports `--description-file`; check `glab mr create --help` if uncertain.
- Never add a "Validation" heading and associated bullet points to MR description.
- For MR creation, never improvise alternative CLI flags. Use known-good command shape from this skill exactly.

### MR creation order

1. `git push -u origin <branch>`
2. write MR body to temp file
3. run:
   `glab mr create --source-branch <branch> --target-branch main --title "<title>" --description "$(cat "$tmpfile")" --yes`

Fallback:

- if title/body already good from commits, `glab mr create --fill --yes`
- do not switch to push options for multiline descriptions
