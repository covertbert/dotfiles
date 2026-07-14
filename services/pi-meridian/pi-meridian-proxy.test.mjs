import assert from "node:assert/strict";
import http from "node:http";
import { afterEach, test } from "node:test";

import {
  createProxyServer,
  rewritePiDocsSection
} from "./pi-meridian-proxy.mjs";

const servers = new Set();

async function listen(server) {
  servers.add(server);

  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });

  return server.address().port;
}

async function close(server) {
  if (!server.listening) {
    servers.delete(server);
    return;
  }

  server.closeAllConnections?.();
  await new Promise((resolve) => server.close(resolve));
  servers.delete(server);
}

afterEach(async () => {
  await Promise.all([...servers].map(close));
});

test("rewrites both Pi documentation prompt sections", () => {
  const parsed = {
    system: [
      {
        type: "text",
        text: [
          "Before",
          "- When asked about: extensions (docs/extensions.md, examples/extensions/), themes (docs/themes.md), skills (docs/skills.md), prompt templates (docs/prompt-templates.md), TUI components (docs/tui.md), keybindings (docs/keybindings.md), SDK integrations (docs/sdk.md), custom providers (docs/custom-provider.md), adding models (docs/models.md), pi packages (docs/packages.md)",
          "- When working on pi topics, read the docs and examples, and follow .md cross-references before implementing",
          "After"
        ].join("\n")
      }
    ]
  };

  assert.equal(rewritePiDocsSection(parsed), 2);
  assert.match(parsed.system[0].text, /- Pi topic guide:/);
  assert.match(
    parsed.system[0].text,
    /inspect only the documentation that is directly relevant/
  );
  assert.doesNotMatch(parsed.system[0].text, /When asked about: extensions/);
});

test("leaves unrelated and non-array system content unchanged", () => {
  const unrelated = { system: [{ type: "text", text: "Keep this text" }] };
  const nonArray = { system: "Keep this text" };

  assert.equal(rewritePiDocsSection(unrelated), 0);
  assert.deepEqual(unrelated, {
    system: [{ type: "text", text: "Keep this text" }]
  });
  assert.equal(rewritePiDocsSection(nonArray), 0);
  assert.deepEqual(nonArray, { system: "Keep this text" });
});

test("forwards health responses from Meridian", async () => {
  const upstream = http.createServer((req, res) => {
    assert.equal(req.url, "/health");
    res.writeHead(200, {
      "content-type": "application/json",
      "x-upstream": "meridian"
    });
    res.end('{"status":"healthy"}');
  });
  const upstreamPort = await listen(upstream);
  const proxy = createProxyServer({ targetPort: upstreamPort });
  const proxyPort = await listen(proxy);

  const response = await fetch(`http://127.0.0.1:${proxyPort}/health`);

  assert.equal(response.status, 200);
  assert.equal(response.headers.get("x-upstream"), "meridian");
  assert.deepEqual(await response.json(), { status: "healthy" });
});

test("forwards invalid JSON without changing request body", async () => {
  const receivedBodies = [];
  const upstream = http.createServer((req, res) => {
    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => {
      const body = Buffer.concat(chunks).toString("utf8");
      receivedBodies.push(body);
      res.end(body);
    });
  });
  const upstreamPort = await listen(upstream);
  const proxy = createProxyServer({ targetPort: upstreamPort });
  const proxyPort = await listen(proxy);
  const body = "{not-json}\n";

  const response = await fetch(`http://127.0.0.1:${proxyPort}/v1/messages`, {
    method: "POST",
    body
  });

  assert.equal(await response.text(), body);
  assert.deepEqual(receivedBodies, [body]);
});

test("warns once when Pi prompt no longer matches expected sections", async () => {
  const warnings = [];
  const logger = {
    warn: (message) => warnings.push(message)
  };
  const upstream = http.createServer((req, res) => {
    req.resume();
    req.on("end", () => res.end("{}"));
  });
  const upstreamPort = await listen(upstream);
  const proxy = createProxyServer({ targetPort: upstreamPort, logger });
  const proxyPort = await listen(proxy);
  const request = () =>
    fetch(`http://127.0.0.1:${proxyPort}/v1/messages`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-meridian-agent": "pi"
      },
      body: JSON.stringify({
        system: [{ type: "text", text: "Updated Pi prompt" }]
      })
    });

  await request();
  await request();

  assert.equal(warnings.length, 1);
  assert.match(warnings[0], /matched 0\/2 expected sections/);
});
