import { readOpenAICodexAuth } from "../auth.ts";
import {
  codexRateLimitDebug,
  mergeUsageWithCachedCodexRateLimits
} from "../codex-rate-limit-cache.ts";
import { formatUsage, remainingFromUsed } from "../format.ts";
import type {
  NormalizedQuotaUsage,
  NormalizedQuotaWindow,
  QuotaAdapter,
  QuotaResult
} from "./types.ts";

const USAGE_URLS = [
  "https://chatgpt.com/backend-api/wham/usage",
  "https://chatgpt.com/backend-api/codex/usage"
] as const;

const FETCH_TIMEOUT_MS = 10_000;

interface UsageWindow {
  used_percent?: number;
  limit_window_seconds?: number;
  reset_at?: number;
  reset_after_seconds?: number;
}

interface UsageResponse {
  rate_limit?: {
    primary_window?: UsageWindow | null;
    secondary_window?: UsageWindow | null;
  };
}

function isoResetAt(window: UsageWindow, nowMs: number): string | null {
  if (typeof window.reset_at === "number")
    return new Date(window.reset_at * 1000).toISOString();
  if (typeof window.reset_after_seconds === "number") {
    return new Date(
      nowMs + Math.max(0, window.reset_after_seconds * 1000)
    ).toISOString();
  }
  return null;
}

function normalizeWindow(
  window: UsageWindow | null | undefined,
  nowMs: number
): NormalizedQuotaWindow | null {
  if (
    !window ||
    typeof window.used_percent !== "number" ||
    !Number.isFinite(window.used_percent)
  )
    return null;
  return {
    remainingPct: remainingFromUsed(window.used_percent),
    resetAt: isoResetAt(window, nowMs)
  };
}

function windowKind(
  window: UsageWindow | null | undefined
): "fiveHour" | "weekly" | undefined {
  const seconds = window?.limit_window_seconds;
  if (typeof seconds !== "number") return undefined;
  if (seconds <= 6 * 60 * 60) return "fiveHour";
  if (seconds >= 6 * 24 * 60 * 60) return "weekly";
  return undefined;
}

export function normalizeOpenAIUsage(
  usage: UsageResponse | undefined,
  nowMs: number
): NormalizedQuotaUsage {
  const primary = usage?.rate_limit?.primary_window;
  const secondary = usage?.rate_limit?.secondary_window;
  const result: NormalizedQuotaUsage = { fiveHour: null, weekly: null };

  for (const window of [primary, secondary]) {
    const normalized = normalizeWindow(window, nowMs);
    if (!normalized) continue;
    const kind = windowKind(window);
    if (kind === "fiveHour") result.fiveHour = normalized;
    if (kind === "weekly") result.weekly = normalized;
  }

  // Old API shape: primary was 5h, secondary was weekly, without explicit durations.
  if (!result.fiveHour && !result.weekly && (primary || secondary)) {
    result.fiveHour = normalizeWindow(primary, nowMs);
    result.weekly = normalizeWindow(secondary, nowMs);
  }

  return result;
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

export class OpenAICodexAdapter implements QuotaAdapter {
  readonly name = "openai-codex";

  constructor(private readonly nowMs: () => number = () => Date.now()) {}

  debug(): Record<string, unknown> {
    return {
      hasAuth: Boolean(readOpenAICodexAuth()),
      urls: [...USAGE_URLS],
      streamRateLimits: codexRateLimitDebug()
    };
  }

  async fetch(): Promise<QuotaResult> {
    const auth = readOpenAICodexAuth();
    if (!auth)
      return {
        status: "unknown",
        reason: "missing openai-codex auth",
        source: this.name
      };

    const headers = {
      Authorization: `Bearer ${auth.access}`,
      "chatgpt-account-id": auth.accountId,
      originator: "pi",
      "User-Agent": "pi"
    };

    let lastError: unknown;
    for (const url of USAGE_URLS) {
      try {
        const nowMs = this.nowMs();
        const raw = (await fetchJsonWithTimeout(
          url,
          { headers },
          FETCH_TIMEOUT_MS
        )) as UsageResponse;
        const endpointUsage = normalizeOpenAIUsage(raw, nowMs);
        const merged = mergeUsageWithCachedCodexRateLimits(
          endpointUsage,
          nowMs
        );
        const usage = merged.usage;
        if (!usage.fiveHour && !usage.weekly) continue;
        const display = formatUsage(usage, nowMs);
        const source =
          merged.filledFiveHour || merged.filledWeekly
            ? `${this.name}+stream`
            : this.name;
        return usage.fiveHour && usage.weekly
          ? { status: "ok", display, usage, source }
          : { status: "partial", display, usage, source };
      } catch (error) {
        lastError = error;
      }
    }

    return {
      status: "unknown",
      reason:
        lastError instanceof Error ? lastError.message : "usage fetch failed",
      source: this.name
    };
  }
}
