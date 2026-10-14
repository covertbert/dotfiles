# quota-status

Local Pi extension. Not published.

Publishes one `ctx.ui.setStatus("quota", ...)` value for the active provider. The
installed `pi-powerline-footer` default preset renders it in its
`extension_statuses` segment, and `/quota` prints the same text.

## Footer formats

Rolling rate-limit windows (`openai-codex`):

```txt
5h(82%, 1h30m) Wk(91%, 3.00d)
```

- `100%` = full usage remaining, `0%` = no usage remaining.
- `5h` = rolling five-hour window, `Wk` = weekly/seven-day window.
- Colour follows the lowest remaining window: muted green at `>=30%`, muted
  amber at `10-29%`, muted red below `10%`.

Monthly organization budget (`anthropic`):

```txt
Mo($496, 99%, 18.58d)
```

- `$496` = remaining of the local `$500` monthly budget.
- `99%` = remaining share of that budget.
- `18.58d` = time until the next UTC month.

## Commands

```txt
/quota
/quota --json
/quota-refresh
/quota-debug
```

`/quota-debug` prints metadata only. It never prints credential values or
session content.

## Supported providers

`openai-codex` and `anthropic`. Other providers show `n/a`.

### anthropic

Anthropic documents no endpoint that returns a live prepaid-credit or
organization balance, and the beta effective spend-limit endpoint
(`/v1/organizations/spend_limits/effective`) returns HTTP 400 for a Claude
Console organization. The displayed balance is therefore derived:

- Completed UTC days come from the Admin Cost Report API
  (`GET /v1/organizations/cost_report`), summing each bucket's `amount`, which
  Anthropic reports as a decimal string in USD cents. Only buckets that ended
  at or before today's `00:00 UTC` are counted.
- The current UTC day comes from local Pi session files: assistant messages
  whose `provider` is `anthropic` and that carry a computed
  `usage.cost.total`, counted from `max(today's 00:00 UTC,
2026-10-13T09:44:22Z)`. The second boundary is the first Pi request sent
  through the Anthropic API key; earlier organization spend belongs to the
  retired subscription and proxy path and is reported by the Admin API instead.
- Month-to-date spend is the API's completed-day total plus the local
  current-day total. The two ranges do not overlap, so nothing is counted
  twice.

Known limits:

- The `$500` budget is a local constant. Anthropic's own tier cap is separate
  and is not read from the API; reaching it produces HTTP 429 responses.
- Pi and other Anthropic clients both contribute to the Admin API totals, so
  the footer tracks whole-organization spend, not only this session.
- Current-day usage from outside local Pi is invisible until Anthropic
  publishes that day. Immediately after `00:00 UTC` the total can briefly
  undercount for the same reason.
- Anthropic documents roughly five-minute reporting latency and sustained
  polling at one request per minute. The extension refreshes at that interval
  and after model turns.
- If the local session root is unreadable the result is `partial` and shows
  completed days only, instead of presenting the total as complete.

## Auth

`anthropic` reads `ANTHROPIC_ADMIN_API_KEY` from the environment. The cost
endpoint requires an Admin API key (`sk-ant-admin01-...`); workspace and model
API keys are rejected. The key is never read from tracked configuration and is
never printed.

`openai-codex` reads `~/.pi/agent/auth.json` by default, overridable with
`PI_QUOTA_AUTH_PATH`:

```json
{
  "openai-codex": {
    "access": "<bearer-token>",
    "accountId": "<account-id>"
  }
}
```

## Paths

Local current-day cost reads Pi session files from
`PI_CODING_AGENT_SESSION_DIR` when set, otherwise `<agent-dir>/sessions`. The
agent directory is `PI_CODING_AGENT_DIR` or `~/.pi/agent`.

## Test

```sh
node --experimental-strip-types --test tests/quota-status-anthropic.test.ts
```
