---
name: php-symfony
description: Use when working in a PHP or Symfony repository, running PHP tests, static analysis (Psalm, PHP CS Fixer), or Docker-based checks. Covers required Docker Compose workflow and test scope rules.
---

# PHP / Symfony

## Static checks

- Run all static checks (Psalm, PHP CS Fixer) via the provided Docker Compose before marking a task complete.
- If Docker Desktop is not running, stop and ask the user to start it before continuing.

## Tests

- Run PHPUnit only for files you deem to have changed. Do not run the full suite unless specifically asked.
