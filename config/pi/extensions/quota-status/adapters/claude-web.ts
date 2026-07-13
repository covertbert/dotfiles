import { readClaudeWebAuth } from "../auth.ts";
import { formatUsage, remainingFromUsed } from "../format.ts";
import type {
  NormalizedQuotaUsage,
  NormalizedQuotaWindow,
  QuotaAdapter,
  QuotaResult
} from "./types.ts";

const CLAUDE_USER_AGENT =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36";
const FETCH_TIMEOUT_MS = 10_000;

interface ClaudeUsageWindow {
  utilization: number;
  resets_at: string | null;
}

interface ClaudeUsageResponse {
  five_hour?: ClaudeUsageWindow | null;
  seven_day?: ClaudeUsageWindow | null;
}

function usageUrl(organizationUuid: string): string {
  return `https://claude.ai/api/organizations/${organizationUuid}/usage`;
}

function asObject(value: unknown): Record<string, unknown> | undefined {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined;
}

function parseWindow(raw: unknown): ClaudeUsageWindow | null {
  const object = asObject(raw);
  if (!object) return null;
  const utilization =
    typeof object.utilization === "number" &&
    Number.isFinite(object.utilization)
      ? object.utilization
      : undefined;
  if (utilization === undefined) return null;
  const resets_at =
    object.resets_at === null
      ? null
      : typeof object.resets_at === "string"
        ? object.resets_at
        : null;
  return { utilization, resets_at };
}

function parseUsage(raw: unknown): ClaudeUsageResponse {
  const object = asObject(raw);
  if (!object) return {};
  return {
    five_hour:
      "five_hour" in object ? parseWindow(object.five_hour) : undefined,
    seven_day: "seven_day" in object ? parseWindow(object.seven_day) : undefined
  };
}

function normalizeWindow(
  window: ClaudeUsageWindow | null | undefined
): NormalizedQuotaWindow | null {
  if (!window) return null;
  return {
    remainingPct: remainingFromUsed(window.utilization),
    resetAt: window.resets_at
  };
}

export function normalizeClaudeUsage(
  usage: ClaudeUsageResponse
): NormalizedQuotaUsage {
  return {
    fiveHour: normalizeWindow(usage.five_hour),
    weekly: normalizeWindow(usage.seven_day)
  };
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

export class ClaudeWebAdapter implements QuotaAdapter {
  readonly name = "claude-web";

  constructor(private readonly nowMs: () => number = () => Date.now()) {}

  debug(): Record<string, unknown> {
    const auth = readClaudeWebAuth();
    return {
      hasAuth: Boolean(auth),
      hasOrganizationUuid: Boolean(auth?.organizationUuid),
      hasCookie: Boolean(auth?.authCookie),
      headerKeys: auth?.headers ? Object.keys(auth.headers) : []
    };
  }

  async fetch(): Promise<QuotaResult> {
    const auth = readClaudeWebAuth();
    if (!auth)
      return {
        status: "unknown",
        reason: "missing claude web auth",
        source: this.name
      };

    try {
      const raw = await fetchJsonWithTimeout(
        usageUrl(auth.organizationUuid),
        {
          headers: {
            accept: "application/json",
            referer: "https://claude.ai/settings/usage",
            "user-agent": CLAUDE_USER_AGENT,
            ...(auth.headers ?? {}),
            cookie: auth.authCookie
          }
        },
        FETCH_TIMEOUT_MS
      );
      const usage = normalizeClaudeUsage(parseUsage(raw));
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
