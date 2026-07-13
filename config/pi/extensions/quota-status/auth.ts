import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const QUOTA_STATUS_KEY = "quota-status";

export interface OpenAICodexAuth {
  access: string;
  accountId: string;
}

export interface ClaudeWebAuth {
  organizationUuid: string;
  authCookie: string;
  headers?: Record<string, string>;
}

export interface ProxyQuotaConfig {
  usageUrl: string;
  headers?: Record<string, string>;
}

export function authPath(): string {
  return (
    process.env.PI_QUOTA_AUTH_PATH ??
    join(homedir(), ".pi", "agent", "auth.json")
  );
}

function readJson(
  path: string = authPath()
): Record<string, unknown> | undefined {
  try {
    return JSON.parse(readFileSync(path, "utf8")) as Record<string, unknown>;
  } catch {
    return undefined;
  }
}

function asObject(value: unknown): Record<string, unknown> | undefined {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined;
}

function asHeaders(value: unknown): Record<string, string> | undefined {
  const object = asObject(value);
  if (!object) return undefined;
  const headers = Object.fromEntries(
    Object.entries(object).filter(
      (entry): entry is [string, string] => typeof entry[1] === "string"
    )
  );
  return Object.keys(headers).length > 0 ? headers : undefined;
}

function quotaStatusProvider(key: string): Record<string, unknown> | undefined {
  return asObject(asObject(readJson()?.[QUOTA_STATUS_KEY])?.[key]);
}

export function readOpenAICodexAuth(): OpenAICodexAuth | undefined {
  const raw = asObject(readJson()?.["openai-codex"]);
  const access = typeof raw?.access === "string" ? raw.access : undefined;
  const accountId =
    typeof raw?.accountId === "string" ? raw.accountId : undefined;
  if (!access || !accountId) return undefined;
  return { access, accountId };
}

export function readClaudeWebAuth(): ClaudeWebAuth | undefined {
  const raw =
    quotaStatusProvider("anthropic-subscription") ??
    quotaStatusProvider("claude-web");

  const organizationUuid =
    process.env.PI_QUOTA_CLAUDE_ORG_UUID ??
    (typeof raw?.organizationUuid === "string"
      ? raw.organizationUuid
      : undefined) ??
    (typeof raw?.organization_uuid === "string"
      ? raw.organization_uuid
      : undefined) ??
    (typeof raw?.orgUuid === "string" ? raw.orgUuid : undefined);

  const authCookie =
    process.env.PI_QUOTA_CLAUDE_COOKIE ??
    (typeof raw?.authCookie === "string" ? raw.authCookie : undefined) ??
    (typeof raw?.cookie === "string" ? raw.cookie : undefined);

  if (!organizationUuid || !authCookie) return undefined;

  let envHeaders: Record<string, string> | undefined;
  if (process.env.PI_QUOTA_CLAUDE_HEADERS_JSON) {
    try {
      envHeaders = asHeaders(
        JSON.parse(process.env.PI_QUOTA_CLAUDE_HEADERS_JSON)
      );
    } catch {
      envHeaders = undefined;
    }
  }

  const headers = { ...(asHeaders(raw?.headers) ?? {}), ...(envHeaders ?? {}) };
  return {
    organizationUuid,
    authCookie,
    ...(Object.keys(headers).length > 0 ? { headers } : {})
  };
}

export function readProxyQuotaConfig(): ProxyQuotaConfig | undefined {
  const raw = quotaStatusProvider("proxy") ?? quotaStatusProvider("meridian");
  const usageUrl =
    process.env.PI_QUOTA_PROXY_USAGE_URL ??
    process.env.PI_QUOTA_MERIDIAN_USAGE_URL ??
    (typeof raw?.usageUrl === "string" ? raw.usageUrl : undefined) ??
    (typeof raw?.url === "string" ? raw.url : undefined);
  if (!usageUrl) return undefined;
  return {
    usageUrl,
    ...(asHeaders(raw?.headers) ? { headers: asHeaders(raw?.headers) } : {})
  };
}

export function authDebug(): Record<string, unknown> {
  const auth = readJson();
  const quotaStatus = asObject(auth?.[QUOTA_STATUS_KEY]);
  return {
    authPath: authPath(),
    hasOpenAICodex: Boolean(
      asObject(auth?.["openai-codex"])?.access &&
      asObject(auth?.["openai-codex"])?.accountId
    ),
    hasClaudeWeb: Boolean(readClaudeWebAuth()),
    hasProxyQuota: Boolean(readProxyQuotaConfig()),
    quotaStatusKeys: quotaStatus ? Object.keys(quotaStatus) : [],
    env: {
      PI_QUOTA_AUTH_PATH: Boolean(process.env.PI_QUOTA_AUTH_PATH),
      PI_QUOTA_CLAUDE_ORG_UUID: Boolean(process.env.PI_QUOTA_CLAUDE_ORG_UUID),
      PI_QUOTA_CLAUDE_COOKIE: Boolean(process.env.PI_QUOTA_CLAUDE_COOKIE),
      PI_QUOTA_CLAUDE_HEADERS_JSON: Boolean(
        process.env.PI_QUOTA_CLAUDE_HEADERS_JSON
      ),
      PI_QUOTA_PROXY_USAGE_URL: Boolean(process.env.PI_QUOTA_PROXY_USAGE_URL),
      PI_QUOTA_MERIDIAN_USAGE_URL: Boolean(
        process.env.PI_QUOTA_MERIDIAN_USAGE_URL
      )
    }
  };
}
