---
name: node-npm
description: Use when working in an NPM or Node.js repository, running npm scripts, linting with ESLint, installing packages, or selecting a Node version. Covers fnm and .nvmrc requirements and resolving lint warnings.
---

# Node / NPM

## Node version

- Always use fnm + `.nvmrc` for Node/npm versions.
- Run `fnm use --install-if-missing` before Node/npm commands when shell auto-switching is unavailable.
- Do not use a hardcoded Node version or assume system Node.

## ESLint

- Fix ESLint warnings in code you created or modified, not just errors. Use `--max-warnings 0` to surface the full set, then resolve warnings in touched code.
- Do not ask whether to fix warnings in untouched code. Report them in one line and leave them alone; unrelated cleanup belongs in its own change.
- Do not silence warnings with inline `eslint-disable` unless the rule is genuinely wrong for the case; state why when suppressing.
