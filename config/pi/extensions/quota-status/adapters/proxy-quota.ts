import { readProxyQuotaConfig } from "../auth.ts";
import { formatUsage, remainingFromUsed } from "../format.ts";
import type {
  NormalizedQuotaUsage,
  NormalizedQuotaWindow,
  QuotaAdapter,
  QuotaResult
} from "./types.ts";

const FETCH_TIMEOUT_MS = 10_000;

function asObject(value: unknown): Record<string, unknown> | undefined {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined;
}

function asNumber(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value)
    ? value
    : undefined;
}

function asStringOrNull(value: unknown): string | null {
  return value === null ? null : typeof value === "string" ? value : null;
}

function normalizeGenericWindow(
  raw: unknown,
  nowMs: number
): NormalizedQuotaWindow | null {
  const object = asObject(raw);
  if (!object) return null;

  const remainingPct =
    asNumber(object.remainingPct) ?? asNumber(object.remaining_percent);
  if (remainingPct !== undefined) {
    return {
      remainingPct: Math.max(0, Math.min(100, remainingPct)),
      resetAt: asStringOrNull(object.resetAt ?? object.reset_at)
    };
  }

  const usedPct = asNumber(object.used_percent) ?? asNumber(object.utilization);
  if (usedPct === undefined) return null;

  let resetAt = asStringOrNull(
    object.resetAt ?? object.reset_at ?? object.resets_at
  );
  const resetAfterSeconds = asNumber(object.reset_after_seconds);
  if (!resetAt && resetAfterSeconds !== undefined) {
    resetAt = new Date(
      nowMs + Math.max(0, resetAfterSeconds * 1000)
    ).toISOString();
  }

  return {
    remainingPct: remainingFromUsed(usedPct),
    resetAt
  };
}

function rateLimitWindowKind(raw: unknown): "fiveHour" | "weekly" | undefined {
  const seconds = asNumber(asObject(raw)?.limit_window_seconds);
  if (seconds === undefined) return undefined;
  if (seconds <= 6 * 60 * 60) return "fiveHour";
  if (seconds >= 6 * 24 * 60 * 60) return "weekly";
  return undefined;
}

export function normalizeProxyUsage(
  raw: unknown,
  nowMs: number
): NormalizedQuotaUsage {
  const object = asObject(raw);
  const rateLimit = asObject(object?.rate_limit);
  const result: NormalizedQuotaUsage = {
    fiveHour: normalizeGenericWindow(
      object?.fiveHour ?? object?.five_hour,
      nowMs
    ),
    weekly: normalizeGenericWindow(
      object?.weekly ?? object?.week ?? object?.seven_day,
      nowMs
    )
  };

  const primary = rateLimit?.primary_window;
  const secondary = rateLimit?.secondary_window;
  for (const window of [primary, secondary]) {
    const normalized = normalizeGenericWindow(window, nowMs);
    if (!normalized) continue;
    const kind = rateLimitWindowKind(window);
    if (kind === "fiveHour") result.fiveHour = normalized;
    if (kind === "weekly") result.weekly = normalized;
  }

  if (!result.fiveHour && !result.weekly && (primary || secondary)) {
    result.fiveHour = normalizeGenericWindow(primary, nowMs);
    result.weekly = normalizeGenericWindow(secondary, nowMs);
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

export class ProxyQuotaAdapter implements QuotaAdapter {
  readonly name = "proxy-quota";

  constructor(private readonly nowMs: () => number = () => Date.now()) {}

  debug(): Record<string, unknown> {
    const config = readProxyQuotaConfig();
    return {
      configured: Boolean(config),
      usageUrl: config?.usageUrl,
      headerKeys: config?.headers ? Object.keys(config.headers) : []
    };
  }

  async fetch(): Promise<QuotaResult> {
    const config = readProxyQuotaConfig();
    if (!config)
      return {
        status: "unknown",
        reason: "proxy quota not configured",
        source: this.name
      };

    try {
      const raw = await fetchJsonWithTimeout(
        config.usageUrl,
        { headers: { accept: "application/json", ...(config.headers ?? {}) } },
        FETCH_TIMEOUT_MS
      );
      const usage = normalizeProxyUsage(raw, this.nowMs());
      if (!usage.fiveHour && !usage.weekly)
        return {
          status: "unknown",
          reason: "missing usage windows",
          source: this.name
        };
      const display = formatUsage(usage, this.nowMs());
      return usage.fiveHour && usage.weekly
        ? { status: "ok", display, usage, source: this.name }
        : { status: "partial", display, usage, source: this.name };
    } catch (error) {
      return {
        status: "unknown",
        reason: error instanceof Error ? error.message : "usage fetch failed",
        source: this.name
      };
    }
  }
}
