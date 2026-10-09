---
name: node-npm
description: Use when working in an NPM or Node.js repository, running npm scripts, installing packages, or selecting a Node version. Covers fnm and .nvmrc requirements.
---

# Node / NPM

## Node version

- Always use fnm + `.nvmrc` for Node/npm versions.
- Run `fnm use --install-if-missing` before Node/npm commands when shell auto-switching is unavailable.
- Do not use a hardcoded Node version or assume system Node.

## ESLint

- Fix all ESLint warnings, not just errors. Do not stop at exit 0; run with `--max-warnings 0` to surface the full set, then resolve each.
- Do not silence warnings with inline `eslint-disable` unless the rule is genuinely wrong for the case; state why when suppressing.
