---
name: git-workflow
description: Use when committing code, creating a branch, creating or updating a pull/merge request, pushing a branch, writing commit messages, or preparing change submissions. Covers lightweight conventional commits, pushes, and MR creation with intent/scope descriptions.
---

# Git Workflow

Follow this workflow directly for branch creation, commits, pushes, and merge requests. Optimise for fast common paths. Escalate only when tripwires appear.

## Core rules

- If user clearly asks to commit, push, or open an MR, treat that as intent.
- Do not add extra confirmation unless a tripwire appears.
- Use byte-capped read-only git commands.
- Prefer status/stat/log summaries over full diffs.
- Do not run destructive commands without explicit confirmation.
- Never use `git add .` unless user explicitly asks.

## Tripwires

Pause and ask, or run deeper checks, when any apply:

- dirty worktree before push or MR
- branch behind/diverged from upstream
- force push required
- no upstream and branch name/remote is unclear
- risky files touched: secrets, `.env*`, credentials, auth, migrations, infra, lockfiles
- many deletes/renames or unusually large diff
- commit/MR intent unclear from request, branch, staged files, or commits
- user asks for review
- command is destructive or irreversible

## Branch naming

When asked to create or name a branch:

1. Run:
   - `git status --short 2>&1 | head -c 4000`
   - `git log --oneline -5 2>&1 | head -c 1000`
2. Propose a kebab-case branch name using `type/short-description`.
3. Output proposed branch name and checkout command.
4. Run checkout command if user asked to create branch and no tripwire appears.

Example:

```bash
git checkout -b feat/add-login
```

## Commit fast path

When asked to commit or draft a commit:

1. Run:
   - `git status --short 2>&1 | head -c 4000`
   - `git diff --staged --stat 2>&1 | head -c 4000`
2. If staged changes exist, infer commit message from staged paths/stat and user request.
3. If no staged changes exist:
   - stage only files the user named, if any
   - otherwise list changed files and ask what to stage
4. Use Conventional Commit format: `type(scope): summary`.
5. Allowed types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`, `build`, `perf`.
6. Summary must be concise and imperative.
7. Commit immediately if user asked to commit and no tripwire appears.

Run deeper checks only if a tripwire appears:

```bash
git diff --staged 2>&1 | head -c 12000
git diff 2>&1 | head -c 12000
```

## Push fast path

When asked to push:

1. Run:
   - `git status -sb 2>&1 | head -c 4000`
2. If branch is clean and tracking upstream, push:
   - `git push`
3. If no upstream but current branch/remote are clear, push:
   - `git push -u origin "$(git branch --show-current)"`
4. If dirty, behind/diverged, force-push needed, or upstream unclear, pause and explain risk.

Run deeper checks only if a tripwire appears:

```bash
git log --oneline @{u}..HEAD 2>/dev/null | head -c 1000
git log --oneline -10 2>&1 | head -c 1000
```

## Merge request fast path

MRs must always include an explicit plain-Markdown description with exactly these two sections:

```md
## intent

...

## scope

...
```

Do not add a `Validation` section. Do not include escaped newline sequences like `\n`.

When asked to open or update an MR:

1. Run:
   - `git status -sb 2>&1 | head -c 4000`
   - `git branch --show-current 2>&1 | head -c 1000`
   - `git log --oneline origin/HEAD..HEAD 2>/dev/null | head -c 2000`
   - `git diff origin/HEAD...HEAD --stat 2>/dev/null | head -c 2000`
2. If branch is not pushed, push before creating MR.
3. Derive title from branch and commits.
4. Draft short `intent` and `scope` from user request, commit summaries, and diff stat.
5. Create MR using a temp file for the description.

Known-good MR flow:

```bash
git push -u origin <branch>
tmpfile="$(mktemp)"
cat > "$tmpfile" <<'EOF'
## intent

...

## scope

...
EOF
glab mr create --source-branch <branch> --target-branch main --title "<title>" --description "$(cat "$tmpfile")" --yes
rm -f "$tmpfile"
```

Do not use `glab mr create --fill --yes` by itself because it does not guarantee the required intent/scope description.
Do not use git push options for multiline MR descriptions.
Do not assume `glab` supports `--description-file`; check `glab mr create --help` if uncertain.

Run deeper checks only if a tripwire appears:

```bash
git log --oneline @{u}..HEAD 2>/dev/null | head -c 2000
git diff origin/HEAD...HEAD 2>/dev/null | head -c 12000
```
