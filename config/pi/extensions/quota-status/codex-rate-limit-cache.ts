import {
  appendFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  statSync,
  writeFileSync
} from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import type {
  NormalizedQuotaUsage,
  NormalizedQuotaWindow
} from "./adapters/types.ts";
import { remainingFromUsed } from "./format.ts";

const CACHE_MAX_AGE_MS = 8 * 60 * 60 * 1000;
const OBSERVER_KEY = Symbol.for("quota-status.codex-rate-limit-observer");

export interface CodexRateLimitCacheEntry {
  capturedAt: number;
  source: "sse" | "websocket" | "codex-session" | "manual";
  eventType?: string;
  usage: NormalizedQuotaUsage;
}

interface ObserverState {
  installed: boolean;
  originalFetch?: typeof fetch;
  originalWebSocket?: typeof WebSocket;
  handlers: Set<(entry: CodexRateLimitCacheEntry) => void>;
}

interface WindowLike {
  used_percent?: unknown;
  remainingPct?: unknown;
  remaining_percent?: unknown;
  window_minutes?: unknown;
  limit_window_seconds?: unknown;
  resets_at?: unknown;
  reset_at?: unknown;
  reset_after_seconds?: unknown;
}

let memoryCache: CodexRateLimitCacheEntry | undefined;

export function codexRateLimitCachePath(): string {
  return (
    process.env.PI_QUOTA_CODEX_RATE_LIMIT_CACHE_PATH ??
    join(homedir(), ".pi", "agent", "quota-status-codex-rate-limits.json")
  );
}

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

function isUsage(value: unknown): value is NormalizedQuotaUsage {
  const object = asObject(value);
  return Boolean(object && "fiveHour" in object && "weekly" in object);
}

function isCacheEntry(value: unknown): value is CodexRateLimitCacheEntry {
  const object = asObject(value);
  return Boolean(
    object &&
    typeof object.capturedAt === "number" &&
    typeof object.source === "string" &&
    isUsage(object.usage)
  );
}

function readCacheFile(): CodexRateLimitCacheEntry | undefined {
  try {
    const parsed = JSON.parse(
      readFileSync(codexRateLimitCachePath(), "utf8")
    ) as unknown;
    return isCacheEntry(parsed) ? parsed : undefined;
  } catch {
    return undefined;
  }
}

function writeCacheFile(entry: CodexRateLimitCacheEntry): void {
  const path = codexRateLimitCachePath();
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(entry, null, 2)}\n`, { mode: 0o600 });
}

function resetAtFromWindow(window: WindowLike, nowMs: number): string | null {
  const rawReset = asNumber(window.resets_at) ?? asNumber(window.reset_at);
  if (rawReset !== undefined) {
    const millis = rawReset > 100_000_000_000 ? rawReset : rawReset * 1000;
    return new Date(millis).toISOString();
  }

  const resetAfterSeconds = asNumber(window.reset_after_seconds);
  if (resetAfterSeconds !== undefined) {
    return new Date(
      nowMs + Math.max(0, resetAfterSeconds * 1000)
    ).toISOString();
  }

  return null;
}

function normalizeWindow(
  raw: unknown,
  nowMs: number
): NormalizedQuotaWindow | null {
  const window = asObject(raw) as WindowLike | undefined;
  if (!window) return null;

  const remaining =
    asNumber(window.remainingPct) ?? asNumber(window.remaining_percent);
  if (remaining !== undefined) {
    return {
      remainingPct: Math.max(0, Math.min(100, remaining)),
      resetAt: resetAtFromWindow(window, nowMs)
    };
  }

  const used = asNumber(window.used_percent);
  if (used === undefined) return null;

  return {
    remainingPct: remainingFromUsed(used),
    resetAt: resetAtFromWindow(window, nowMs)
  };
}

function windowKind(
  raw: unknown,
  fallback: "fiveHour" | "weekly" | undefined
): "fiveHour" | "weekly" | undefined {
  const window = asObject(raw) as WindowLike | undefined;
  const minutes = asNumber(window?.window_minutes);
  if (minutes !== undefined) {
    if (minutes <= 360) return "fiveHour";
    if (minutes >= 6 * 24 * 60) return "weekly";
  }

  const seconds = asNumber(window?.limit_window_seconds);
  if (seconds !== undefined) {
    if (seconds <= 6 * 60 * 60) return "fiveHour";
    if (seconds >= 6 * 24 * 60 * 60) return "weekly";
  }

  return fallback;
}

function normalizeRateLimitObject(
  raw: unknown,
  nowMs: number
): NormalizedQuotaUsage | undefined {
  const object = asObject(raw);
  if (!object) return undefined;

  const result: NormalizedQuotaUsage = { fiveHour: null, weekly: null };
  const primary = object.primary ?? object.primary_window;
  const secondary = object.secondary ?? object.secondary_window;

  const candidates: Array<[unknown, "fiveHour" | "weekly" | undefined]> = [
    [primary, "primary_window" in object ? undefined : "fiveHour"],
    [secondary, "secondary_window" in object ? undefined : "weekly"]
  ];

  for (const [window, fallback] of candidates) {
    const normalized = normalizeWindow(window, nowMs);
    if (!normalized) continue;
    const kind = windowKind(window, fallback);
    if (kind === "fiveHour") result.fiveHour = normalized;
    if (kind === "weekly") result.weekly = normalized;
  }

  return result.fiveHour || result.weekly ? result : undefined;
}

function debugRateLimitFrame(
  value: unknown,
  source: CodexRateLimitCacheEntry["source"]
): void {
  const debugPath = process.env.PI_QUOTA_CODEX_DEBUG_FRAMES;
  if (!debugPath) return;
  const object = asObject(value);
  try {
    appendFileSync(
      debugPath,
      `${JSON.stringify({
        capturedAt: new Date().toISOString(),
        source,
        type: object?.type,
        keys: object ? Object.keys(object) : [],
        rate_limits: object?.rate_limits,
        rate_limit: object?.rate_limit,
        additional_rate_limits: object?.additional_rate_limits,
        code_review_rate_limits: object?.code_review_rate_limits
      })}\n`,
      "utf8"
    );
  } catch {
    // noop
  }
}

function findRateLimitUsage(
  value: unknown,
  nowMs: number,
  depth = 0
): NormalizedQuotaUsage | undefined {
  if (depth > 5) return undefined;
  const object = asObject(value);
  if (!object) return undefined;

  const direct =
    normalizeRateLimitObject(object.rate_limits, nowMs) ??
    normalizeRateLimitObject(object.rate_limit, nowMs);
  if (direct) return direct;

  if (
    "primary" in object ||
    "secondary" in object ||
    "primary_window" in object ||
    "secondary_window" in object
  ) {
    const normalized = normalizeRateLimitObject(object, nowMs);
    if (normalized) return normalized;
  }

  for (const child of Object.values(object)) {
    if (Array.isArray(child)) {
      for (const item of child) {
        const nested = findRateLimitUsage(item, nowMs, depth + 1);
        if (nested) return nested;
      }
      continue;
    }
    const nested = findRateLimitUsage(child, nowMs, depth + 1);
    if (nested) return nested;
  }

  return undefined;
}

export function captureCodexRateLimits(
  value: unknown,
  source: CodexRateLimitCacheEntry["source"]
): CodexRateLimitCacheEntry | undefined {
  const nowMs = Date.now();
  debugRateLimitFrame(value, source);
  const usage = findRateLimitUsage(value, nowMs);
  if (!usage) return undefined;

  const entry: CodexRateLimitCacheEntry = {
    capturedAt: nowMs,
    source,
    eventType:
      typeof asObject(value)?.type === "string"
        ? String(asObject(value)?.type)
        : undefined,
    usage
  };

  memoryCache = entry;
  try {
    writeCacheFile(entry);
  } catch {
    // Cache is best-effort. Keep memory copy for current process.
  }

  notifyCapture(entry);
  return entry;
}

function windowStillUseful(
  window: NormalizedQuotaWindow | null,
  nowMs: number
): boolean {
  if (!window) return false;
  if (!window.resetAt) return true;
  const resetMs = Date.parse(window.resetAt);
  return Number.isFinite(resetMs) && resetMs > nowMs;
}

function codexSessionsDir(): string {
  return join(process.env.CODEX_HOME ?? join(homedir(), ".codex"), "sessions");
}

function collectJsonlFiles(root: string): string[] {
  const files: Array<{ path: string; mtimeMs: number }> = [];
  const visit = (dir: string) => {
    let entries: ReturnType<typeof readdirSync>;
    try {
      entries = readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }

    for (const entry of entries) {
      const path = join(dir, entry.name);
      if (entry.isDirectory()) {
        visit(path);
        continue;
      }
      if (!entry.isFile() || !entry.name.endsWith(".jsonl")) continue;
      try {
        files.push({ path, mtimeMs: statSync(path).mtimeMs });
      } catch {
        // noop
      }
    }
  };

  visit(root);
  return files
    .sort((a, b) => b.mtimeMs - a.mtimeMs)
    .slice(0, 80)
    .map((file) => file.path);
}

function readLatestCodexSessionRateLimits(
  nowMs: number
): CodexRateLimitCacheEntry | undefined {
  for (const file of collectJsonlFiles(codexSessionsDir())) {
    let lines: string[];
    try {
      lines = readFileSync(file, "utf8").trim().split("\n").reverse();
    } catch {
      continue;
    }

    for (const line of lines) {
      try {
        const parsed = JSON.parse(line) as unknown;
        const object = asObject(parsed);
        const payload = object?.payload ?? parsed;
        const usage = findRateLimitUsage(payload, nowMs);
        if (!usage) continue;
        const capturedAt =
          typeof object?.timestamp === "string" &&
          Number.isFinite(Date.parse(object.timestamp))
            ? Date.parse(object.timestamp)
            : statSync(file).mtimeMs;
        const entry: CodexRateLimitCacheEntry = {
          capturedAt,
          source: "codex-session",
          eventType:
            typeof asObject(payload)?.type === "string"
              ? String(asObject(payload)?.type)
              : undefined,
          usage
        };
        if (
          windowStillUseful(entry.usage.fiveHour, nowMs) ||
          windowStillUseful(entry.usage.weekly, nowMs)
        )
          return entry;
      } catch {
        // noop
      }
    }
  }

  return undefined;
}

function mergeCacheEntries(
  primary: CodexRateLimitCacheEntry | undefined,
  fallback: CodexRateLimitCacheEntry | undefined,
  nowMs: number
): CodexRateLimitCacheEntry | undefined {
  if (!primary) return fallback;
  if (!fallback) return primary;

  const fiveHour = windowStillUseful(primary.usage.fiveHour, nowMs)
    ? primary.usage.fiveHour
    : windowStillUseful(fallback.usage.fiveHour, nowMs)
      ? fallback.usage.fiveHour
      : null;
  const weekly = windowStillUseful(primary.usage.weekly, nowMs)
    ? primary.usage.weekly
    : windowStillUseful(fallback.usage.weekly, nowMs)
      ? fallback.usage.weekly
      : null;

  return {
    ...primary,
    capturedAt: Math.max(primary.capturedAt, fallback.capturedAt),
    source: primary.source,
    usage: { fiveHour, weekly }
  };
}

export function getCachedCodexRateLimits(
  nowMs: number = Date.now()
): CodexRateLimitCacheEntry | undefined {
  const primary = memoryCache ?? readCacheFile();
  const fallback = readLatestCodexSessionRateLimits(nowMs);
  const entry = mergeCacheEntries(primary, fallback, nowMs);
  if (!entry) return undefined;
  memoryCache = entry;

  const hasUsefulWindow =
    windowStillUseful(entry.usage.fiveHour, nowMs) ||
    windowStillUseful(entry.usage.weekly, nowMs);
  if (nowMs - entry.capturedAt > CACHE_MAX_AGE_MS && !hasUsefulWindow)
    return undefined;
  return entry;
}

export function mergeUsageWithCachedCodexRateLimits(
  usage: NormalizedQuotaUsage,
  nowMs: number = Date.now()
): {
  usage: NormalizedQuotaUsage;
  cache: CodexRateLimitCacheEntry | undefined;
  filledFiveHour: boolean;
  filledWeekly: boolean;
} {
  const cache = getCachedCodexRateLimits(nowMs);
  if (!cache)
    return {
      usage,
      cache: undefined,
      filledFiveHour: false,
      filledWeekly: false
    };

  const cachedFiveHour = windowStillUseful(cache.usage.fiveHour, nowMs)
    ? cache.usage.fiveHour
    : null;
  const cachedWeekly = windowStillUseful(cache.usage.weekly, nowMs)
    ? cache.usage.weekly
    : null;

  const filledFiveHour = !usage.fiveHour && Boolean(cachedFiveHour);
  const filledWeekly = !usage.weekly && Boolean(cachedWeekly);

  return {
    usage: {
      fiveHour: usage.fiveHour ?? cachedFiveHour,
      weekly: usage.weekly ?? cachedWeekly
    },
    cache,
    filledFiveHour,
    filledWeekly
  };
}

function shouldObserveUrl(input: unknown): boolean {
  const raw =
    typeof input === "string"
      ? input
      : input instanceof URL
        ? input.toString()
        : typeof Request !== "undefined" && input instanceof Request
          ? input.url
          : typeof input === "object" && input !== null && "url" in input
            ? String((input as { url?: unknown }).url ?? "")
            : "";

  if (!raw) return false;
  try {
    const url = new URL(
      raw.replace(/^wss:/, "https:").replace(/^ws:/, "http:")
    );
    return (
      url.pathname.endsWith("/codex/responses") ||
      url.pathname.includes("/backend-api/codex/responses")
    );
  } catch {
    return raw.includes("/codex/responses");
  }
}

function observeJsonText(
  text: string,
  source: CodexRateLimitCacheEntry["source"]
): void {
  const trimmed = text.trim();
  if (!trimmed || trimmed === "[DONE]") return;
  try {
    captureCodexRateLimits(JSON.parse(trimmed), source);
  } catch {
    // Ignore non-JSON frames.
  }
}

async function observeSseResponse(response: Response): Promise<void> {
  if (!response.body) return;
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      let boundary = buffer.indexOf("\n\n");
      while (boundary !== -1) {
        const chunk = buffer.slice(0, boundary);
        buffer = buffer.slice(boundary + 2);
        const data = chunk
          .split("\n")
          .filter((line) => line.startsWith("data:"))
          .map((line) => line.slice(5).trim())
          .join("\n")
          .trim();
        observeJsonText(data, "sse");
        boundary = buffer.indexOf("\n\n");
      }
    }
  } catch {
    // Observability must never break provider stream.
  } finally {
    try {
      reader.releaseLock();
    } catch {
      // noop
    }
  }
}

async function decodeWebSocketData(data: unknown): Promise<string | undefined> {
  if (typeof data === "string") return data;
  if (data instanceof ArrayBuffer)
    return new TextDecoder().decode(new Uint8Array(data));
  if (ArrayBuffer.isView(data)) {
    const view = data as ArrayBufferView;
    return new TextDecoder().decode(
      new Uint8Array(view.buffer, view.byteOffset, view.byteLength)
    );
  }
  if (
    data &&
    typeof data === "object" &&
    "arrayBuffer" in data &&
    typeof (data as { arrayBuffer?: unknown }).arrayBuffer === "function"
  ) {
    const arrayBuffer = await (
      data as { arrayBuffer(): Promise<ArrayBuffer> }
    ).arrayBuffer();
    return new TextDecoder().decode(new Uint8Array(arrayBuffer));
  }
  return undefined;
}

function getObserverState(): ObserverState {
  const globalWithState = globalThis as typeof globalThis & {
    [OBSERVER_KEY]?: ObserverState;
  };
  globalWithState[OBSERVER_KEY] ??= { installed: false, handlers: new Set() };
  return globalWithState[OBSERVER_KEY];
}

function notifyCapture(entry: CodexRateLimitCacheEntry): void {
  const state = getObserverState();
  for (const handler of state.handlers) {
    try {
      handler(entry);
    } catch {
      // noop
    }
  }
}

export function installCodexRateLimitObserver(
  onCapture?: (entry: CodexRateLimitCacheEntry) => void
): () => void {
  const state = getObserverState();
  if (onCapture) state.handlers.add(onCapture);

  if (!state.installed) {
    state.originalFetch = globalThis.fetch;
    state.originalWebSocket = globalThis.WebSocket;

    if (typeof state.originalFetch === "function") {
      const originalFetch = state.originalFetch;
      globalThis.fetch = (async (
        input: RequestInfo | URL,
        init?: RequestInit
      ) => {
        const response = await originalFetch(input, init);
        if (shouldObserveUrl(input)) {
          try {
            void observeSseResponse(response.clone());
          } catch {
            // noop
          }
        }
        return response;
      }) as typeof fetch;
    }

    if (typeof state.originalWebSocket === "function") {
      const OriginalWebSocket = state.originalWebSocket;
      const ObservableWebSocket = class extends OriginalWebSocket {
        constructor(
          url: string | URL,
          protocols?: string | string[] | Record<string, unknown>
        ) {
          super(url, protocols as string | string[] | undefined);
          if (!shouldObserveUrl(url)) return;
          this.addEventListener("message", (event: MessageEvent) => {
            void (async () => {
              try {
                const text = await decodeWebSocketData(event.data);
                if (text) observeJsonText(text, "websocket");
              } catch {
                // noop
              }
            })();
          });
        }
      };
      globalThis.WebSocket = ObservableWebSocket as typeof WebSocket;
    }

    state.installed = true;
  }

  return () => {
    if (onCapture) state.handlers.delete(onCapture);
    if (state.handlers.size > 0 || !state.installed) return;

    if (state.originalFetch) globalThis.fetch = state.originalFetch;
    if (state.originalWebSocket) globalThis.WebSocket = state.originalWebSocket;
    state.originalFetch = undefined;
    state.originalWebSocket = undefined;
    state.installed = false;
  };
}

export function codexRateLimitDebug(): Record<string, unknown> {
  const cache = getCachedCodexRateLimits();
  const state = getObserverState();
  return {
    cachePath: codexRateLimitCachePath(),
    cacheFileExists: existsSync(codexRateLimitCachePath()),
    observerInstalled: state.installed,
    observerHandlers: state.handlers.size,
    hasCache: Boolean(cache),
    capturedAt: cache ? new Date(cache.capturedAt).toISOString() : null,
    source: cache?.source ?? null,
    eventType: cache?.eventType ?? null,
    hasFiveHour: Boolean(cache?.usage.fiveHour),
    hasWeekly: Boolean(cache?.usage.weekly)
  };
}
