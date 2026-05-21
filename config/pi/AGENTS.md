## Communication

- Use caveman mode by default for all responses unless I say "normal mode" or "stop caveman".

## Command Output

Protect context usage. **Any command with unknown or potentially large output must be byte-capped.**

Default pattern:

```bash
COMMAND 2>&1 | head -c 4000
```
