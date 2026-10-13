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
  const raw = asObject(readJson()?.["openai-codex"]);
  const access = typeof raw?.access === "string" ? raw.access : undefined;
  const accountId =
    typeof raw?.accountId === "string" ? raw.accountId : undefined;
  if (!access || !accountId) return undefined;
  return { access, accountId };
}

export function authDebug(): Record<string, unknown> {
  return {
    authPath: authPath(),
    hasOpenAICodex: Boolean(readOpenAICodexAuth()),
    env: {
      PI_QUOTA_AUTH_PATH: Boolean(process.env.PI_QUOTA_AUTH_PATH)
    }
  };
}
