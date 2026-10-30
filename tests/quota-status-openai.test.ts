import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { readOpenAICodexAuth } from "../config/pi/extensions/quota-status/auth.ts";

function withAuthFiles(
  piAuth: unknown,
  codexAuth: unknown,
  run: () => void
): void {
  const root = mkdtempSync(join(tmpdir(), "quota-status-openai-"));
  const piAuthPath = join(root, "pi-auth.json");
  const codexHome = join(root, "codex");
  mkdirSync(codexHome);
  writeFileSync(piAuthPath, JSON.stringify(piAuth));
  writeFileSync(join(codexHome, "auth.json"), JSON.stringify(codexAuth));

  const oldPiAuthPath = process.env.PI_QUOTA_AUTH_PATH;
  const oldCodexHome = process.env.CODEX_HOME;
  process.env.PI_QUOTA_AUTH_PATH = piAuthPath;
  process.env.CODEX_HOME = codexHome;
  try {
    run();
  } finally {
    if (oldPiAuthPath === undefined) delete process.env.PI_QUOTA_AUTH_PATH;
    else process.env.PI_QUOTA_AUTH_PATH = oldPiAuthPath;
    if (oldCodexHome === undefined) delete process.env.CODEX_HOME;
    else process.env.CODEX_HOME = oldCodexHome;
    rmSync(root, { recursive: true, force: true });
  }
}

test("reads Codex CLI OAuth credentials when Pi auth has no legacy Codex entry", () => {
  withAuthFiles(
    { openai: { type: "oauth", access: "new-token" } },
    {
      tokens: {
        access_token: "codex-token",
        account_id: "codex-account"
      }
    },
    () => {
      assert.deepEqual(readOpenAICodexAuth(), {
        access: "codex-token",
        accountId: "codex-account"
      });
    }
  );
});

test("prefers legacy Pi Codex credentials when present", () => {
  withAuthFiles(
    {
      "openai-codex": { access: "pi-token", accountId: "pi-account" }
    },
    {
      tokens: {
        access_token: "codex-token",
        account_id: "codex-account"
      }
    },
    () => {
      assert.deepEqual(readOpenAICodexAuth(), {
        access: "pi-token",
        accountId: "pi-account"
      });
    }
  );
});
