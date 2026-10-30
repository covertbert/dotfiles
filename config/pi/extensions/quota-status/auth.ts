import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export interface OpenAICodexAuth {
  access: string;
  accountId: string;
}

export function authPath(): string {
  return (
    process.env.PI_QUOTA_AUTH_PATH ??
    join(homedir(), ".pi", "agent", "auth.json")
  );
}

export function codexAuthPath(): string {
  return join(process.env.CODEX_HOME ?? join(homedir(), ".codex"), "auth.json");
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

export function readOpenAICodexAuth(): OpenAICodexAuth | undefined {
  const piAuth = asObject(readJson()?.["openai-codex"]);
  const codexTokens = asObject(readJson(codexAuthPath())?.tokens);
  const credentials = [
    { access: piAuth?.access, accountId: piAuth?.accountId },
    {
      access: codexTokens?.access_token,
      accountId: codexTokens?.account_id
    }
  ];

  for (const credential of credentials) {
    if (
      typeof credential.access === "string" &&
      typeof credential.accountId === "string"
    )
      return { access: credential.access, accountId: credential.accountId };
  }
  return undefined;
}

export function readAnthropicAdminKey(): string | undefined {
  const key = process.env.ANTHROPIC_ADMIN_API_KEY;
  return typeof key === "string" && key.trim().length > 0 ? key : undefined;
}

export function authDebug(): Record<string, unknown> {
  return {
    authPath: authPath(),
    codexAuthPath: codexAuthPath(),
    hasOpenAICodex: Boolean(readOpenAICodexAuth()),
    hasAnthropicAdminKey: Boolean(readAnthropicAdminKey()),
    env: {
      PI_QUOTA_AUTH_PATH: Boolean(process.env.PI_QUOTA_AUTH_PATH),
      ANTHROPIC_ADMIN_API_KEY: Boolean(process.env.ANTHROPIC_ADMIN_API_KEY)
    }
  };
}
