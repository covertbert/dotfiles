import type { QuotaAdapter } from "./adapters/types.ts";
import { AnthropicAdminAdapter } from "./adapters/anthropic.ts";
import { OpenAICodexAdapter } from "./adapters/openai-codex.ts";

const openAICodexAdapter = new OpenAICodexAdapter();

export const PROVIDER_ADAPTERS: Record<string, QuotaAdapter> = {
  openai: openAICodexAdapter,
  "openai-codex": openAICodexAdapter,
  anthropic: new AnthropicAdminAdapter()
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
