import type { QuotaAdapter, QuotaResult } from "./adapters/types.ts";
import { ClaudeWebAdapter } from "./adapters/claude-web.ts";
import { OpenAICodexAdapter } from "./adapters/openai-codex.ts";
import { ProxyQuotaAdapter } from "./adapters/proxy-quota.ts";

class FallbackAdapter implements QuotaAdapter {
  readonly name: string;

  constructor(private readonly adapters: QuotaAdapter[]) {
    this.name = adapters.map((adapter) => adapter.name).join("→");
  }

  debug(): Record<string, unknown> {
    return Object.fromEntries(
      this.adapters.map((adapter) => [adapter.name, adapter.debug?.() ?? {}])
    );
  }

  async fetch(params?: {
    cwd?: string;
    signal?: AbortSignal;
  }): Promise<QuotaResult> {
    let lastUnknown: Extract<QuotaResult, { status: "unknown" }> | undefined;
    for (const adapter of this.adapters) {
      const result = await adapter.fetch(params);
      if (result.status !== "unknown") return result;
      lastUnknown = result;
    }
    return (
      lastUnknown ?? {
        status: "unknown",
        reason: "no adapter result",
        source: this.name
      }
    );
  }
}

const claudeFallback = new FallbackAdapter([
  new ProxyQuotaAdapter(),
  new ClaudeWebAdapter()
]);

export const PROVIDER_ADAPTERS: Record<string, QuotaAdapter> = {
  "openai-codex": new OpenAICodexAdapter(),
  anthropic: claudeFallback,
  "claude-bridge": claudeFallback,
  meridian: claudeFallback
};

export function getQuotaAdapter(
  provider: string | undefined
): QuotaAdapter | undefined {
  return provider ? PROVIDER_ADAPTERS[provider] : undefined;
}

export function hasQuotaAdapter(
  provider: string | undefined
): provider is string {
  return Boolean(provider && PROVIDER_ADAPTERS[provider]);
}

export function registryDebug(
  provider: string | undefined
): Record<string, unknown> {
  const adapter = getQuotaAdapter(provider);
  return {
    provider: provider ?? null,
    supported: Boolean(adapter),
    supportedProviders: Object.keys(PROVIDER_ADAPTERS),
    adapter: adapter?.name ?? null,
    adapterDebug: adapter?.debug?.() ?? null
  };
}
