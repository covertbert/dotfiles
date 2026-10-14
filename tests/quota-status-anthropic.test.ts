import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import {
  AnthropicAdminAdapter,
  completedDayCostUsd,
  localAnthropicCostUsd
} from "../config/pi/extensions/quota-status/adapters/anthropic.ts";
import { statusLevel } from "../config/pi/extensions/quota-status/format.ts";

const NOW_MS = Date.parse("2026-10-13T10:00:00Z");
const DAY_START_MS = Date.parse("2026-10-13T00:00:00Z");
// 2026-10-13T10:00Z -> 2026-11-01T00:00Z
const RESET_DURATION_TEXT = "18.58d";

function costReport(
  buckets: Array<{ ending_at: string; amount: string }>
): unknown {
  return {
    data: buckets.map((bucket) => ({
      starting_at: bucket.ending_at,
      ending_at: bucket.ending_at,
      results: [{ amount: bucket.amount, currency: "USD" }]
    })),
    has_more: false,
    next_page: null
  };
}

function withAdminKey<T>(value: string | undefined, run: () => T): T {
  const saved = process.env.ANTHROPIC_ADMIN_API_KEY;
  if (value === undefined) delete process.env.ANTHROPIC_ADMIN_API_KEY;
  else process.env.ANTHROPIC_ADMIN_API_KEY = value;
  try {
    return run();
  } finally {
    if (saved === undefined) delete process.env.ANTHROPIC_ADMIN_API_KEY;
    else process.env.ANTHROPIC_ADMIN_API_KEY = saved;
  }
}

test("completedDayCostUsd excludes the in-progress UTC day", () => {
  const total = completedDayCostUsd(
    costReport([
      { ending_at: "2026-10-13T00:00:00Z", amount: "120.5" },
      { ending_at: "2026-10-14T00:00:00Z", amount: "9999.0" }
    ]),
    DAY_START_MS
  );
  assert.equal(total, 1.205);
});

test("completedDayCostUsd rejects malformed reports", () => {
  assert.throws(
    () => completedDayCostUsd({ data: [], has_more: true }, DAY_START_MS),
    /pagination/
  );
  assert.throws(
    () =>
      completedDayCostUsd(
        {
          data: [
            {
              ending_at: "2026-10-13T00:00:00Z",
              results: [{ amount: "1", currency: "EUR" }]
            }
          ]
        },
        DAY_START_MS
      ),
    /currency/
  );
  assert.throws(
    () =>
      completedDayCostUsd(
        {
          data: [
            {
              ending_at: "2026-10-13T00:00:00Z",
              results: [{ amount: "not-a-number", currency: "USD" }]
            }
          ]
        },
        DAY_START_MS
      ),
    /amount/
  );
  assert.throws(() => completedDayCostUsd(null, DAY_START_MS), /shape/);
});

test("adapter adds today's local Pi cost to completed API days", async () => {
  const adapter = new AnthropicAdminAdapter({
    nowMs: () => NOW_MS,
    fetchCostReport: async () =>
      costReport([{ ending_at: "2026-10-13T00:00:00Z", amount: "0.00" }]),
    readLocalCost: () => 3.782834
  });

  const result = await withAdminKey("sk-ant-admin01-test", () =>
    adapter.fetch()
  );
  assert.equal(result.status, "ok");
  if (result.status !== "ok") return;
  assert.equal(result.source, "anthropic-admin+local");
  assert.equal(result.display, `Mo($496, 99%, ${RESET_DURATION_TEXT})`);
  assert.ok(result.usage.monthly);
  assert.equal(
    result.usage.monthly.remaining.toFixed(6),
    (500 - 3.782834).toFixed(6)
  );
  assert.equal(result.usage.monthly.remainingPct.toFixed(4), "99.2434");
  assert.equal(statusLevel(result.usage), "normal");
});

test("adapter degrades to partial when the local session root is unusable", async () => {
  const adapter = new AnthropicAdminAdapter({
    nowMs: () => NOW_MS,
    fetchCostReport: async () =>
      costReport([{ ending_at: "2026-10-13T00:00:00Z", amount: "0.00" }]),
    readLocalCost: () => undefined
  });

  const result = await withAdminKey("sk-ant-admin01-test", () =>
    adapter.fetch()
  );
  assert.equal(result.status, "partial");
  if (result.status !== "partial") return;
  assert.equal(result.source, "anthropic-admin");
  assert.equal(result.display, `Mo($500, 100%, ${RESET_DURATION_TEXT})`);
});

test("adapter reports unknown without an admin credential", async () => {
  const adapter = new AnthropicAdminAdapter({
    nowMs: () => NOW_MS,
    fetchCostReport: async () => {
      throw new Error("must not be called");
    },
    readLocalCost: () => 0
  });

  const result = await withAdminKey(undefined, () => adapter.fetch());
  assert.equal(result.status, "unknown");
  if (result.status !== "unknown") return;
  assert.equal(result.reason, "missing ANTHROPIC_ADMIN_API_KEY");
});

test("adapter floors the remaining budget and reports error level past $500", async () => {
  const adapter = new AnthropicAdminAdapter({
    nowMs: () => NOW_MS,
    fetchCostReport: async () =>
      costReport([{ ending_at: "2026-10-13T00:00:00Z", amount: "60000" }]),
    readLocalCost: () => 0
  });

  const result = await withAdminKey("sk-ant-admin01-test", () =>
    adapter.fetch()
  );
  assert.equal(result.status, "ok");
  if (result.status !== "ok") return;
  assert.equal(result.display, `Mo($0, 0%, ${RESET_DURATION_TEXT})`);
  assert.equal(result.usage.monthly?.remaining, 0);
  assert.equal(result.usage.monthly?.remainingPct, 0);
  assert.equal(statusLevel(result.usage), "error");
});

test("localAnthropicCostUsd reads only Anthropic assistant usage metadata", () => {
  const root = mkdtempSync(join(tmpdir(), "quota-status-anthropic-"));
  try {
    const nowMs = Date.now();
    const sinceMs = nowMs - 60 * 60 * 1000;
    const iso = (ms: number) => new Date(ms).toISOString();
    const lines = [
      {
        type: "message",
        timestamp: iso(nowMs),
        message: {
          role: "assistant",
          provider: "anthropic",
          usage: { cost: { total: 1.5 } }
        }
      },
      {
        type: "message",
        timestamp: iso(nowMs),
        message: {
          role: "assistant",
          provider: "openai-codex",
          usage: { cost: { total: 99 } }
        }
      },
      {
        type: "message",
        timestamp: iso(nowMs),
        message: {
          role: "user",
          provider: "anthropic",
          usage: { cost: { total: 42 } }
        }
      },
      {
        type: "message",
        timestamp: iso(sinceMs - 60 * 1000),
        message: {
          role: "assistant",
          provider: "anthropic",
          usage: { cost: { total: 50 } }
        }
      },
      {
        type: "message",
        timestamp: iso(nowMs + 60 * 1000),
        message: {
          role: "assistant",
          provider: "anthropic",
          usage: { cost: { total: 2 } }
        }
      }
    ];
    writeFileSync(
      join(root, "session.jsonl"),
      `${lines.map((line) => JSON.stringify(line)).join("\n")}\n`
    );

    assert.equal(localAnthropicCostUsd(root, sinceMs), 3.5);
    assert.equal(
      localAnthropicCostUsd(join(root, "does-not-exist"), sinceMs),
      undefined
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
