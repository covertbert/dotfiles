---
name: git-workflow
description: Use when committing code, creating a branch, creating or updating a pull/merge request, pushing a branch, writing commit messages, or preparing change submissions. Covers lightweight conventional commits, pushes, MR creation with reviewer-led descriptions, testing tables and diagrams, and keeping the MR title and description current as commits land.
---

# Git Workflow

Follow this workflow directly for branch creation, commits, pushes, and merge requests. Optimise for fast common paths. Escalate only when tripwires appear.

## Delegation

When a `subagent` tool is available, delegate the whole workflow once to the `git-workflow` agent instead of running the steps below in this session:

- Enable subagents first if the session exposes only `subagents_enable`.
- Pass the user's exact request and any files they named.
- Include any preflight output you already ran, so the child does not repeat those reads.
- Do not run Git or `glab` mutations while the child owns the workflow. Inspect its result instead.
- If the delegation cannot start, follow this skill directly.

The sections below are the contract the child executes. An agent without a `subagent` tool runs them directly.

## Batching and parallelism

Git and `glab` commands take milliseconds; each separate tool message costs a full model round trip of seconds. Reduce round trips, not command time.

- Run every read-only command for a step in one `bash` call, with labelled `echo` separators, byte-capped once at the end.
- Chain dependent mutations in one call with `&&`, so a failure stops the chain before the next mutation runs.
- Never spawn subagents to parallelise Git or `glab` work. Spawn cost exceeds the commands, and `commit -> push -> MR` is a dependency chain that cannot overlap.
- Subagents are worth it only for work measured in tens of seconds or more: full test suites, CI waits, or review of a very large diff. That work is outside this skill; run it alongside the Git chain, not instead of it.

Batch shape for reads:

```bash
{
  echo "== status ==";  git status -sb
  echo "== branch ==";  git branch --show-current
  echo "== unpushed =="; git log --oneline @{u}..HEAD 2>/dev/null
  echo "== files ==";   git diff --stat 2>/dev/null
  echo "== open mr =="; glab mr view --json title,description 2>&1
} 2>&1 | head -c 8000
```

## Core rules

- If user clearly asks to commit, push, or open an MR, treat that as intent.
- Do not add extra confirmation unless a tripwire appears.
- Use byte-capped read-only git commands, batched one step per call.
- Prefer status/stat/log summaries over full diffs.
- Do not run destructive commands without explicit confirmation.
- Never use `git add .` unless user explicitly asks.
- Fix lint and type warnings only in code created or modified in this change. Report unrelated pre-existing warnings in one line; never ask whether to fix them.
- MR titles must use Conventional Commit format: `type(scope): summary` or `type: summary`.
- MR title types must be one of: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`, `build`, `perf`.

## Tripwires

Pause and ask, or run deeper checks, when any apply:

- dirty worktree before push or MR
- force push required
- commit/MR intent unclear from request, branch, staged files, or commits
- user asks for review
- command is destructive or irreversible

## Branch naming

When asked to create or name a branch:

1. Run:

```bash
{
  echo "== status =="; git status --short
  echo "== branch =="; git branch --show-current
} 2>&1 | head -c 4000
```

2. Create a kebab-case branch name using `type/short-description`.
3. Output proposed branch name and checkout command.
4. Run checkout command if no tripwire appears.

Example:

```bash
git checkout -b feat/add-login
```

## Commit fast path

When asked to commit or draft a commit:

1. Run one batched call:

```bash
{
  echo "== status =="; git status --short
  echo "== staged =="; git diff --staged --stat
} 2>&1 | head -c 4000
```

2. If staged changes exist, infer commit message from staged paths/stat and user request.
3. If no staged changes exist:
   - stage only files the user named, if any
   - otherwise list changed files and ask what to stage
4. Use Conventional Commit format: `type(scope): summary`.
5. Allowed types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`, `build`, `perf`.
6. Summary must be concise and imperative.
7. Commit immediately if user asked to commit and no tripwire appears.

Run deeper checks only if a tripwire appears, in one call:

```bash
{
  echo "== staged diff =="; git diff --staged
  echo "== worktree diff =="; git diff
} 2>&1 | head -c 12000
```

## Push fast path

When asked to push:

1. Run one batched call, including the open MR when one exists:

```bash
{
  echo "== status =="; git status -sb
  echo "== open mr =="; glab mr view --json title,description 2>&1
} 2>&1 | head -c 6000
```

2. If branch is clean and tracking upstream, push:
   - `git push`
3. If no upstream but current branch/remote are clear, push:
   - `git push -u origin "$(git branch --show-current)"`
4. If dirty, force-push needed, or upstream unclear, pause and explain risk.
5. If the branch has an open MR, update its title and description per "Keeping the MR current" below before reporting the push as done.

Run deeper checks only if a tripwire appears, in one call:

```bash
{
  echo "== unpushed =="; git log --oneline @{u}..HEAD 2>/dev/null
  echo "== recent =="; git log --oneline -10
} 2>&1 | head -c 2000
```

## Merge request fast path

MRs are always created as drafts. Pass `--draft` to `glab mr create`; never create a ready MR.

MRs must always include an explicit plain-Markdown description using this template. Headers are questions a newcomer asks, so they double as writing prompts.

```md
## What problem does this solve?

Plain language. Who is affected and what is wrong or missing today. Link the issue if one exists.

## What does it look like now?

| Before | After |
| ------ | ----- |
| ...    | ...   |

<!-- Or a Mermaid flow/sequence diagram when control flow changed rather than UI.
     Omit only for dependency bumps, renames and typos, and say so in one line. -->

## Where should I look?

1. `path/file` — the core change and why it is there
2. `path/file` — follow-on change

## What has been tested?

| What I checked                | How                                         | Outcome    |
| ----------------------------- | ------------------------------------------- | ---------- |
| Wrong password shows an error | `AuthTest::rejectsBadPassword`              | Pass       |
| Login on iOS 17               | Simulator, tapped through with test account | Pass       |
| Large upload over 100 MB      | Not tested, no fixture                      | Not tested |

## What could break?

- risk → mitigation
- say so plainly when there is no known risk

## Out of scope

- work deliberately left for a follow-up
```

Rules for the description:

- Plain Markdown in a temp file. Never include escaped newline sequences like `\n`.
- Write for someone who has never seen this code: short sentences, no unexplained internal jargon or ticket slang.
- `Where should I look?` uses real paths with line hints when helpful. If the change is one file, one entry is enough.
- `What could break?` and `Out of scope` are never empty. "None known" is acceptable; a blank section is not.

### Testing table

Include the table whenever behaviour changed. Column headers stay exactly `What I checked`, `How`, `Outcome` — no `E2E`, `smoke`, `QA phase` or other team vocabulary a newcomer cannot decode.

- `What I checked`: the behaviour a person would notice, in their words. Not test-file names.
- `How`: how it was verified. Automated: the test path or name. Manual: the surface and platform (browser, simulator, device, OS version). State the CI job when the check only ran there.
- `Outcome`: `Pass`, `Fail`, or `Not tested` plus why. Never imply a check ran when it did not.
- One row per behaviour, not per test file. Drop rows that add nothing; keep the risky ones.
- For dependency bumps and typo fixes, a single row saying what was still verified is enough.

### Visuals

Prefer a picture when flow, sequence or layout changed:

- before/after table for UI, output or API shape changes
- `mermaid flowchart LR` for data or control flow, ~8 nodes max
- `sequenceDiagram` for request/call ordering

GitLab renders Mermaid in descriptions. Keep diagrams to the one idea a reviewer needs; do not reproduce the whole system.

When asked to open or update an MR:

1. Run one batched call:

```bash
{
  echo "== status =="; git status -sb
  echo "== branch =="; git branch --show-current
  echo "== unpushed =="; git log --oneline origin/HEAD..HEAD 2>/dev/null
  echo "== files =="; git diff origin/HEAD...HEAD --stat 2>/dev/null
  echo "== open mr =="; glab mr view --json title,description 2>&1
} 2>&1 | head -c 8000
```

2. If branch is not pushed, push before creating MR.
3. Derive title from branch and commits:
   - Derive from branch, commits, and diff stat.
   - Always normalize title to Conventional Commit format: `type(scope): summary` or `type: summary`.
   - Title must match `^(feat|fix|docs|refactor|test|chore|ci|build|perf)(\([a-z0-9-]+\))?: .+`.
   - If type, scope, or summary cannot be inferred, pause and ask.
   - Do not create an MR with a non-conventional title.
4. Draft the description from user request, commit summaries and diff stat, following the template above.
5. Create MR using a temp file for the description.

Known-good MR flow. Write the description first, then run the push, create and cleanup as one chained call. `&&` stops the chain if any step fails, so a failed push never leaves an MR-less commit reported as created:

```bash
branch="$(git branch --show-current)"
tmpfile="$(mktemp)"
cat > "$tmpfile" <<'EOF'
## What problem does this solve?

...

## What does it look like now?

| Before | After |
|---|---|
| ... | ... |

## Where should I look?

1. `path/file` — ...

## What has been tested?

| What I checked | How | Outcome |
|---|---|---|
| ... | ... | Pass |

## What could break?

- ...

## Out of scope

- ...
EOF
git push -u origin "$branch" && \
  glab mr create --draft --source-branch "$branch" --target-branch main --title "feat(scope): summary" --description "$(cat "$tmpfile")" --yes && \
  rm -f "$tmpfile"
```

Do not use raw branch names as MR titles.
Do not omit `--draft`.
Do not use `glab mr create --fill --yes` by itself because it does not guarantee the required description.
Do not use git push options for multiline MR descriptions.
Do not assume `glab` supports `--description-file`; check `glab mr create --help` if uncertain.

Run deeper checks only if a tripwire appears, in one call:

```bash
{
  echo "== unpushed =="; git log --oneline @{u}..HEAD 2>/dev/null
  echo "== diff =="; git diff origin/HEAD...HEAD 2>/dev/null
} 2>&1 | head -c 12000
```

## Keeping the MR current

Every push to an MR branch changes the MR. The description must describe the branch as it is now, not as it was when the MR opened.

After every push to a branch with an open MR:

1. Read the MR and the new branch state in one batched call:

```bash
{
  echo "== mr =="; glab mr view --json title,description
  echo "== unpushed =="; git log --oneline origin/HEAD..HEAD 2>/dev/null
  echo "== files =="; git diff origin/HEAD...HEAD --stat 2>/dev/null
} 2>&1 | head -c 8000
```

2. Update the title when the summary no longer fits the change: `glab mr update --title "type(scope): summary"`.
3. Update the description with a full rewrite from the temp file: `glab mr update --description "$(cat "$tmpfile")"`. Rewrite the affected sections. Never append "update:" logs, changelog bullets or review-fix notes to the description.
4. Extend the testing table when a new commit adds behaviour that was verified. Leave a row alone when nothing was tested.

Chain the title and description update in one call with `&&` when both change:

```bash
glab mr update --title "type(scope): summary" --description "$(cat "$tmpfile")" && rm -f "$tmpfile"
```

Replace stale content rather than layering on top of it: removed code, abandoned approaches, superseded screenshots and diagrams that no longer match the diff all cost more than a short honest description.

The exception is a fixup, rebase or dependency bump that changes nothing a reviewer reads. Then confirm the existing description still matches before leaving it.
