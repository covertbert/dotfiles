import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { QuotaResult } from "./adapters/types.ts";
import { authDebug } from "./auth.ts";
import {
  codexRateLimitDebug,
  installCodexRateLimitObserver,
  type CodexRateLimitCacheEntry
} from "./codex-rate-limit-cache.ts";
import { styleStatus, statusLevel, type ThemeLike } from "./format.ts";
import { getQuotaAdapter, hasQuotaAdapter, registryDebug } from "./registry.ts";

const STATUS_KEY = "quota";
const REFRESH_OK_MS = 60_000;
const REFRESH_RETRY_MS = 15_000;
const STALE_FAILURE_LIMIT = 3;

type ProviderModel = { provider?: string; id?: string };
type PiContext = {
  hasUI?: boolean;
  mode?: string;
  cwd?: string;
  model?: ProviderModel;
  ui: {
    theme?: ThemeLike;
    setStatus(key: string, value: string | undefined): void;
  };
};

type CachedResolved = Extract<QuotaResult, { status: "ok" | "partial" }>;

interface RefreshState {
  cached: CachedResolved | undefined;
  lastAttemptAt: number;
  consecutiveFailures: number;
  lastUnknown: Extract<QuotaResult, { status: "unknown" }> | undefined;
}

interface SessionProviderSnapshot {
  sessionEpoch: number;
  provider?: string;
}

function blankRefreshState(): RefreshState {
  return {
    cached: undefined,
    lastAttemptAt: 0,
    consecutiveFailures: 0,
    lastUnknown: undefined
  };
}

function nextRefreshDelayMs(state: RefreshState): number {
  return state.consecutiveFailures === 0 ? REFRESH_OK_MS : REFRESH_RETRY_MS;
}

function shouldRefresh(state: RefreshState, now: number): boolean {
  return now - state.lastAttemptAt >= nextRefreshDelayMs(state);
}

function sessionProviderKey(snapshot: SessionProviderSnapshot): string {
  return `${snapshot.sessionEpoch}:${snapshot.provider ?? ""}`;
}

function isCurrentSessionProvider(
  expected: SessionProviderSnapshot,
  current: SessionProviderSnapshot
): boolean {
  return (
    expected.sessionEpoch === current.sessionEpoch &&
    expected.provider === current.provider
  );
}

function applyRefreshResult(
  state: RefreshState,
  result: QuotaResult,
  now: number
): RefreshState {
  if (result.status === "ok") {
    return {
      cached: result,
      lastAttemptAt: now,
      consecutiveFailures: 0,
      lastUnknown: undefined
    };
  }

  if (result.status === "partial") {
    const consecutiveFailures = state.consecutiveFailures + 1;
    return {
      cached:
        state.cached && consecutiveFailures < STALE_FAILURE_LIMIT
          ? state.cached
          : result,
      lastAttemptAt: now,
      consecutiveFailures,
      lastUnknown: undefined
    };
  }

  const consecutiveFailures = state.consecutiveFailures + 1;
  return {
    cached:
      consecutiveFailures >= STALE_FAILURE_LIMIT ? undefined : state.cached,
    lastAttemptAt: now,
    consecutiveFailures,
    lastUnknown: result
  };
}

function commandResultText(
  result: Record<string, unknown>,
  json: boolean
): string {
  if (json) return JSON.stringify(result, null, 2);
  if (result.status === "ok" || result.status === "partial")
    return String(result.display);
  if (result.status === "unsupported")
    return `unsupported: ${String(result.provider || "none")}`;
  return `unknown: ${String(result.reason || "quota unavailable")}`;
}

export default function quotaStatus(pi: ExtensionAPI) {
  let ctx: PiContext | undefined;
  let refreshState = blankRefreshState();
  let interval: ReturnType<typeof setInterval> | undefined;
  let cleanupCodexObserver: (() => void) | undefined;
  let activeRefreshKey: string | undefined;
  let lastProvider: string | undefined;
  let sessionEpoch = 0;

  const provider = () => ctx?.model?.provider;
  const modelId = () => ctx?.model?.id;
  const snapshot = (): SessionProviderSnapshot => ({
    sessionEpoch,
    provider: provider()
  });

  const render = () => {
    if (!ctx?.hasUI) return;
    const p = provider();

    if (!hasQuotaAdapter(p)) {
      ctx.ui.setStatus(STATUS_KEY, styleStatus("n/a", ctx.ui.theme, "dim"));
      return;
    }

    if (!refreshState.cached) {
      ctx.ui.setStatus(STATUS_KEY, styleStatus("unknown", ctx.ui.theme, "dim"));
      return;
    }

    ctx.ui.setStatus(
      STATUS_KEY,
      styleStatus(
        refreshState.cached.display,
        ctx.ui.theme,
        statusLevel(refreshState.cached.usage)
      )
    );
  };

  const resetStateIfProviderChanged = () => {
    const p = provider();
    if (p !== lastProvider) {
      refreshState = blankRefreshState();
      lastProvider = p;
    }
  };

  const fetchForProvider = async (
    p: string | undefined,
    cwd: string | undefined
  ): Promise<Record<string, unknown>> => {
    const adapter = getQuotaAdapter(p);
    if (!p || !adapter) {
      return {
        status: "unsupported",
        provider: p ?? "",
        model: modelId() ?? null
      };
    }

    const result = await adapter.fetch({ cwd });
    if (result.status === "unknown") {
      return {
        status: "unknown",
        provider: p,
        model: modelId() ?? null,
        source: result.source,
        reason: result.reason
      };
    }
    return { ...result, provider: p, model: modelId() ?? null };
  };

  const refresh = async (
    force = false
  ): Promise<Record<string, unknown> | undefined> => {
    resetStateIfProviderChanged();
    render();

    const current = snapshot();
    const key = sessionProviderKey(current);
    const adapter = getQuotaAdapter(current.provider);
    if (!adapter)
      return {
        status: "unsupported",
        provider: current.provider ?? "",
        model: modelId() ?? null
      };
    if (!force && !shouldRefresh(refreshState, Date.now())) return undefined;
    if (activeRefreshKey === key) return undefined;

    activeRefreshKey = key;
    try {
      const result = await adapter.fetch({ cwd: ctx?.cwd });
      if (isCurrentSessionProvider(current, snapshot())) {
        refreshState = applyRefreshResult(refreshState, result, Date.now());
      }

      if (result.status === "unknown") {
        return {
          status: "unknown",
          provider: current.provider ?? "",
          model: modelId() ?? null,
          source: result.source,
          reason: result.reason
        };
      }
      return {
        ...result,
        provider: current.provider ?? "",
        model: modelId() ?? null
      };
    } finally {
      if (activeRefreshKey === key) activeRefreshKey = undefined;
      render();
    }
  };

  const tick = () => {
    resetStateIfProviderChanged();
    render();
    if (hasQuotaAdapter(provider()) && shouldRefresh(refreshState, Date.now()))
      void refresh(false);
  };

  const onCodexRateLimitCapture = (_entry: CodexRateLimitCacheEntry) => {
    if (provider() === "openai-codex") void refresh(true);
  };

  const registerUsageCommand = (name: string, description: string) => {
    pi.registerCommand(name, {
      description,
      handler: async (args, cmdCtx) => {
        ctx = cmdCtx as unknown as PiContext;
        const json = args.split(/\s+/).includes("--json");
        const result =
          (await refresh(true)) ??
          (await fetchForProvider(provider(), ctx.cwd));
        const text = commandResultText(result, json);
        if (ctx.mode === "print" || ctx.mode === "json") {
          process.stdout.write(`${text}\n`);
          return;
        }
        pi.sendMessage({ customType: "quota", content: text, display: true });
      }
    });
  };

  registerUsageCommand(
    "quota",
    "Fetch quota for active provider. Use --json for structured output."
  );
  registerUsageCommand(
    "quota-refresh",
    "Force-refresh quota for active provider. Use --json for structured output."
  );

  pi.registerCommand("quota-debug", {
    description: "Show quota provider/auth debug metadata without secrets.",
    handler: async (_args, cmdCtx) => {
      ctx = cmdCtx as unknown as PiContext;
      const output = JSON.stringify(
        {
          provider: provider() ?? null,
          model: modelId() ?? null,
          registry: registryDebug(provider()),
          auth: authDebug(),
          codexRateLimits: codexRateLimitDebug(),
          cache: {
            hasCachedUsage: Boolean(refreshState.cached),
            cachedSource: refreshState.cached?.source ?? null,
            consecutiveFailures: refreshState.consecutiveFailures,
            lastUnknown: refreshState.lastUnknown
              ? {
                  source: refreshState.lastUnknown.source,
                  reason: refreshState.lastUnknown.reason
                }
              : null
          }
        },
        null,
        2
      );
      if (ctx.mode === "print" || ctx.mode === "json") {
        process.stdout.write(`${output}\n`);
        return;
      }
      pi.sendMessage({ customType: "quota", content: output, display: true });
    }
  });

  pi.on("session_start", (_event, nextCtx) => {
    if (interval) clearInterval(interval);
    cleanupCodexObserver?.();
    sessionEpoch += 1;
    ctx = nextCtx as unknown as PiContext;
    lastProvider = undefined;
    refreshState = blankRefreshState();
    cleanupCodexObserver = installCodexRateLimitObserver(
      onCodexRateLimitCapture
    );
    if (!ctx.hasUI) return;
    tick();
    interval = setInterval(tick, 1000);
  });

  pi.on("model_select", (_event, nextCtx) => {
    ctx = nextCtx as unknown as PiContext;
    if (!ctx.hasUI) return;
    tick();
  });

  pi.on("turn_end", () => {
    if (ctx?.hasUI) void refresh(true);
  });

  pi.on("agent_end", () => {
    if (ctx?.hasUI) void refresh(true);
  });

  pi.on("session_compact", () => {
    if (ctx?.hasUI) void refresh(true);
  });

  pi.on("session_shutdown", (_event, shutdownCtx) => {
    sessionEpoch += 1;
    if (interval) clearInterval(interval);
    cleanupCodexObserver?.();
    interval = undefined;
    cleanupCodexObserver = undefined;
    ctx = undefined;
    refreshState = blankRefreshState();
    activeRefreshKey = undefined;
    lastProvider = undefined;
    if ((shutdownCtx as unknown as PiContext).hasUI) {
      (shutdownCtx as unknown as PiContext).ui.setStatus(STATUS_KEY, undefined);
    }
  });
}
