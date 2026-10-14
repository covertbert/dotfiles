import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { readAnthropicAdminKey } from "../auth.ts";
import { resetDuration } from "../format.ts";
import type { QuotaAdapter, QuotaResult } from "./types.ts";

const COST_REPORT_URL =
  "https://api.anthropic.com/v1/organizations/cost_report";
const ANTHROPIC_VERSION = "2023-06-01";
const FETCH_TIMEOUT_MS = 10_000;

/**
 * Local monthly budget. Anthropic's Console enforces the tier cap (HTTP 429),
 * but this budget is the operator's own $500 allowance, so it is a local value
 * rather than something the Admin API reports.
 */
const MONTHLY_BUDGET_USD = 500;

/**
 * Pi first sent Anthropic requests directly through the API key at this commit.
 * Earlier organization spend belongs to the retired subscription/proxy path and
 * must not be counted from local session files.
 */
const DIRECT_API_CUTOVER_MS = Date.parse("2026-10-13T09:44:22Z");

/** Bound the local scan; a day of sessions is far below these limits. */
// ponytail: fixed caps, index sessions incrementally if a day ever exceeds them.
const MAX_SESSION_FILES = 500;
const MAX_SESSION_BYTES = 16 * 1024 * 1024;

function asObject(value: unknown): Record<string, unknown> | undefined {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined;
}

function agentDir(): string {
  return process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
}

export function anthropicSessionRoot(): string {
  return (
    process.env.PI_CODING_AGENT_SESSION_DIR ?? join(agentDir(), "sessions")
  );
}

function utcDayStartMs(nowMs: number): number {
  const now = new Date(nowMs);
  return Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
}

function utcMonthStartMs(nowMs: number): number {
  const now = new Date(nowMs);
  return Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1);
}

function nextUtcMonthStartMs(nowMs: number): number {
  const now = new Date(nowMs);
  return Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1);
}

/**
 * Sum cost-report buckets that ended at or before `dayStartMs`, so the
 * in-progress UTC day is excluded. Anthropic reports `amount` as a decimal
 * string in the lowest currency unit (cents for USD).
 */
export function completedDayCostUsd(
  report: unknown,
  dayStartMs: number
): number {
  const root = asObject(report);
  if (!root) throw new Error("unexpected cost report shape");
  if (root.has_more === true)
    throw new Error("unexpected cost report pagination");
  const data = root.data;
  if (!Array.isArray(data)) throw new Error("unexpected cost report shape");

  let totalCents = 0;
  for (const bucket of data) {
    const bucketObject = asObject(bucket);
    if (!bucketObject) continue;
    const endingAt =
      typeof bucketObject.ending_at === "string"
        ? Date.parse(bucketObject.ending_at)
        : Number.NaN;
    if (!Number.isFinite(endingAt) || endingAt > dayStartMs) continue;

    const results = bucketObject.results;
    if (!Array.isArray(results)) continue;
    for (const result of results) {
      const resultObject = asObject(result);
      if (!resultObject) continue;
      if (resultObject.currency !== "USD")
        throw new Error("unexpected cost currency");
      const amount =
        typeof resultObject.amount === "string"
          ? Number(resultObject.amount)
          : Number.NaN;
      if (!Number.isFinite(amount)) throw new Error("unexpected cost amount");
      totalCents += amount;
    }
  }

  return totalCents / 100;
}

interface SessionCostEntry {
  timestamp?: unknown;
  type?: unknown;
  message?: unknown;
}

function collectSessionFiles(root: string, modifiedSinceMs: number): string[] {
  const files: Array<{ path: string; mtimeMs: number }> = [];

  const visit = (dir: string): void => {
    if (files.length >= MAX_SESSION_FILES) return;
    let entries: ReturnType<typeof readdirSync>;
    try {
      entries = readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const entry of entries) {
      if (files.length >= MAX_SESSION_FILES) return;
      const path = join(dir, entry.name);
      if (entry.isDirectory()) {
        visit(path);
        continue;
      }
      if (!entry.isFile() || !entry.name.endsWith(".jsonl")) continue;
      try {
        const mtimeMs = statSync(path).mtimeMs;
        if (mtimeMs >= modifiedSinceMs) files.push({ path, mtimeMs });
      } catch {
        // Unreadable file: skip.
      }
    }
  };

  visit(root);
  return files.map((file) => file.path);
}

/**
 * Sum Pi's own calculated Anthropic cost for a window, read from session JSONL
 * files. Only message metadata is read: timestamp, role, provider and the
 * computed `usage.cost.total`. Prompt and response content is never parsed.
 */
export function localAnthropicCostUsd(
  root: string,
  sinceMs: number
): number | undefined {
  if (!existsSync(root)) return undefined;

  let total = 0;
  let bytesRead = 0;
  for (const path of collectSessionFiles(root, sinceMs)) {
    let text: string;
    try {
      text = readFileSync(path, "utf8");
    } catch {
      continue;
    }
    bytesRead += text.length;
    if (bytesRead > MAX_SESSION_BYTES)
      throw new Error("session cost scan exceeded byte budget");

    for (const line of text.split("\n")) {
      if (!line.includes('"provider":"anthropic"')) continue;
      let entry: SessionCostEntry;
      try {
        entry = JSON.parse(line) as SessionCostEntry;
      } catch {
        continue;
      }
      if (entry.type !== "message") continue;
      const message = asObject(entry.message);
      if (!message) continue;
      if (message.role !== "assistant" || message.provider !== "anthropic")
        continue;
      const timestamp =
        typeof entry.timestamp === "string"
          ? Date.parse(entry.timestamp)
          : Number.NaN;
      if (!Number.isFinite(timestamp) || timestamp < sinceMs) continue;
      const cost = asObject(asObject(message.usage)?.cost);
      const amount = cost?.total;
      if (typeof amount !== "number" || !Number.isFinite(amount)) continue;
      total += amount;
    }
  }

  return total;
}

async function fetchJsonWithTimeout(
  url: string,
  init: RequestInit,
  timeoutMs: number
): Promise<unknown> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, { ...init, signal: controller.signal });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return await response.json();
  } finally {
    clearTimeout(timeout);
  }
}

export interface AnthropicAdapterDeps {
  nowMs?: () => number;
  /** Overridable for tests; defaults to the live Admin Cost Report call. */
  fetchCostReport?: (params: {
    key: string;
    startingAtMs: number;
    endingAtMs: number;
  }) => Promise<unknown>;
  /** Overridable for tests; `undefined` means the local session root is unusable. */
  readLocalCost?: (params: { sinceMs: number }) => number | undefined;
}

export function formatMonthlyBudget(
  remaining: number,
  remainingPct: number,
  resetAt: string,
  nowMs: number
): string {
  return `Mo($${Math.round(remaining)}, ${Math.round(remainingPct)}%, ${resetDuration(resetAt, nowMs)})`;
}

export class AnthropicAdminAdapter implements QuotaAdapter {
  readonly name = "anthropic-admin";

  private readonly deps: AnthropicAdapterDeps;

  constructor(deps: AnthropicAdapterDeps = {}) {
    this.deps = deps;
  }

  private nowMs(): number {
    return this.deps.nowMs?.() ?? Date.now();
  }

  private fetchCostReport(params: {
    key: string;
    startingAtMs: number;
    endingAtMs: number;
  }): Promise<unknown> {
    if (this.deps.fetchCostReport) return this.deps.fetchCostReport(params);
    const url = new URL(COST_REPORT_URL);
    url.searchParams.set(
      "starting_at",
      new Date(params.startingAtMs).toISOString()
    );
    url.searchParams.set(
      "ending_at",
      new Date(params.endingAtMs).toISOString()
    );
    url.searchParams.set("bucket_width", "1d");
    url.searchParams.set("limit", "31");
    return fetchJsonWithTimeout(
      url.toString(),
      {
        headers: {
          "anthropic-version": ANTHROPIC_VERSION,
          "x-api-key": params.key
        }
      },
      FETCH_TIMEOUT_MS
    );
  }

  private readLocalCost(sinceMs: number): number | undefined {
    if (this.deps.readLocalCost) return this.deps.readLocalCost({ sinceMs });
    try {
      return localAnthropicCostUsd(anthropicSessionRoot(), sinceMs);
    } catch {
      return undefined;
    }
  }

  debug(): Record<string, unknown> {
    const root = anthropicSessionRoot();
    return {
      hasAdminKey: Boolean(readAnthropicAdminKey()),
      budgetUsd: MONTHLY_BUDGET_USD,
      sessionRoot: root,
      sessionRootExists: existsSync(root),
      cutoverAt: new Date(DIRECT_API_CUTOVER_MS).toISOString()
    };
  }

  async fetch(): Promise<QuotaResult> {
    const key = readAnthropicAdminKey();
    if (!key)
      return {
        status: "unknown",
        reason: "missing ANTHROPIC_ADMIN_API_KEY",
        source: this.name
      };

    const nowMs = this.nowMs();
    const dayStartMs = utcDayStartMs(nowMs);

    let completedDayUsd: number;
    try {
      const raw = await this.fetchCostReport({
        key,
        startingAtMs: utcMonthStartMs(nowMs),
        endingAtMs: dayStartMs
      });
      completedDayUsd = completedDayCostUsd(raw, dayStartMs);
    } catch (error) {
      return {
        status: "unknown",
        reason: error instanceof Error ? error.message : "cost report failed",
        source: this.name
      };
    }

    const sinceMs = Math.max(dayStartMs, DIRECT_API_CUTOVER_MS);
    const localUsd = this.readLocalCost(sinceMs);
    const hasLocal = typeof localUsd === "number";
    const spentUsd = completedDayUsd + (hasLocal ? localUsd : 0);

    const remaining = Math.max(0, MONTHLY_BUDGET_USD - spentUsd);
    const remainingPct = Math.max(
      0,
      Math.min(100, (remaining / MONTHLY_BUDGET_USD) * 100)
    );
    const resetAt = new Date(nextUtcMonthStartMs(nowMs)).toISOString();
    const display = formatMonthlyBudget(
      remaining,
      remainingPct,
      resetAt,
      nowMs
    );
    const source = hasLocal ? `${this.name}+local` : this.name;

    const usage = {
      fiveHour: null,
      weekly: null,
      monthly: { remaining, remainingPct, resetAt }
    };

    // `partial` marks a missing local estimate so the footer is not presented
    // as organization-complete when today's Pi spend could not be read.
    return hasLocal
      ? { status: "ok", display, usage, source }
      : { status: "partial", display, usage, source };
  }
}
