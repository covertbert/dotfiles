# quota-status

Local Pi extension. Not published.

Footer format:

```txt
5h(82%, 1h30m) Wk(91%, 3.00d)
```

Meaning:

- `100%` = full usage remaining
- `0%` = no usage remaining
- `5h` = rolling five-hour window
- `Wk` = weekly/seven-day window
- Color uses the lowest remaining quota window: muted green at `>=30%`, muted amber at `10–29%`, muted red below `10%`.

## Commands

```txt
/quota
/quota --json
/quota-refresh
/quota-debug
```

`/quota-debug` prints metadata only. No secrets.

## Supported providers

Only `openai-codex` reports quota. Other providers, including `anthropic`, show `n/a`, because API-key billing has no rolling usage window to read.

## Auth

Reads `~/.pi/agent/auth.json` by default. Override with `PI_QUOTA_AUTH_PATH`.

OpenAI Codex/GPT:

```json
{
  "openai-codex": {
    "access": "<bearer-token>",
    "accountId": "<account-id>"
  }
}
```
