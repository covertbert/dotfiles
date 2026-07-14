#!/usr/bin/env node

import http from "node:http";
import { pathToFileURL } from "node:url";

const DEFAULT_TARGET_HOST = "127.0.0.1";
const DEFAULT_TARGET_PORT = 3456;
const DEFAULT_LISTEN_HOST = "127.0.0.1";
const DEFAULT_LISTEN_PORT = 3457;

const PI_DOCS_REWRITES = [
  [
    "- When asked about: extensions (docs/extensions.md, examples/extensions/), themes (docs/themes.md), skills (docs/skills.md), prompt templates (docs/prompt-templates.md), TUI components (docs/tui.md), keybindings (docs/keybindings.md), SDK integrations (docs/sdk.md), custom providers (docs/custom-provider.md), adding models (docs/models.md), pi packages (docs/packages.md)",
    `- Pi topic guide:
          - extensions: docs/extensions.md and examples/extensions/
          - themes: docs/themes.md
          - skills: docs/skills.md
          - prompt templates: docs/prompt-templates.md
          - TUI components: docs/tui.md
          - keybindings: docs/keybindings.md
          - SDK integrations: docs/sdk.md
          - custom providers: docs/custom-provider.md
          - adding models: docs/models.md
          - Pi packages: docs/packages.md`
  ],
  [
    "- When working on pi topics, read the docs and examples, and follow .md cross-references before implementing",
    "- When working on Pi-specific topics, inspect only the documentation that is directly relevant to the user request before implementing."
  ]
];

export function rewritePiDocsSection(parsed) {
  if (!Array.isArray(parsed?.system)) {
    return 0;
  }

  const matchedRewrites = new Set();

  for (const item of parsed.system) {
    if (!item || item.type !== "text" || typeof item.text !== "string") {
      continue;
    }

    for (const [index, [source, replacement]] of PI_DOCS_REWRITES.entries()) {
      const rewritten = item.text.replace(source, replacement);

      if (rewritten !== item.text) {
        item.text = rewritten;
        matchedRewrites.add(index);
      }
    }
  }

  return matchedRewrites.size;
}

function sendProxyError(res, error) {
  if (res.headersSent) {
    res.destroy(error);
    return;
  }

  res.writeHead(502, { "content-type": "application/json" });
  res.end(JSON.stringify({ error: String(error) }));
}

export function createProxyServer({
  targetHost = DEFAULT_TARGET_HOST,
  targetPort = DEFAULT_TARGET_PORT,
  logger = console
} = {}) {
  let warnedAboutMissingRewrite = false;

  return http.createServer((req, res) => {
    const chunks = [];

    req.on("error", (error) => sendProxyError(res, error));
    req.on("data", (chunk) => chunks.push(chunk));

    req.on("end", () => {
      const body = Buffer.concat(chunks);
      let forwardBody = body;
      const requestPath = new URL(req.url ?? "/", "http://localhost").pathname;

      if (requestPath === "/v1/messages") {
        try {
          const parsed = JSON.parse(body.toString("utf8"));
          const replacementCount = rewritePiDocsSection(parsed);

          if (
            req.headers["x-meridian-agent"] === "pi" &&
            replacementCount < PI_DOCS_REWRITES.length &&
            !warnedAboutMissingRewrite
          ) {
            logger.warn(
              `Pi prompt rewrite matched ${replacementCount}/${PI_DOCS_REWRITES.length} expected sections. Pi prompt text may have changed.`
            );
            warnedAboutMissingRewrite = true;
          }

          forwardBody = Buffer.from(JSON.stringify(parsed));
        } catch {
          forwardBody = body;
        }
      }

      const forwardHeaders = { ...req.headers };
      delete forwardHeaders.host;
      delete forwardHeaders["content-length"];
      delete forwardHeaders["transfer-encoding"];

      const proxyReq = http.request(
        {
          hostname: targetHost,
          port: targetPort,
          path: req.url,
          method: req.method,
          headers: {
            ...forwardHeaders,
            "content-length": String(forwardBody.length)
          }
        },
        (proxyRes) => {
          res.writeHead(proxyRes.statusCode ?? 500, proxyRes.headers);
          proxyRes.pipe(res);
        }
      );

      proxyReq.on("error", (error) => sendProxyError(res, error));

      if (forwardBody.length > 0) {
        proxyReq.write(forwardBody);
      }

      proxyReq.end();
    });
  });
}

function parsePort(value, fallback, name) {
  if (value === undefined) {
    return fallback;
  }

  const port = Number(value);

  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error(`${name} must be an integer between 1 and 65535`);
  }

  return port;
}

export function startProxyFromEnvironment(env = process.env, logger = console) {
  const targetPort = parsePort(
    env.PI_MERIDIAN_TARGET_PORT,
    DEFAULT_TARGET_PORT,
    "PI_MERIDIAN_TARGET_PORT"
  );
  const listenPort = parsePort(
    env.PI_MERIDIAN_LISTEN_PORT,
    DEFAULT_LISTEN_PORT,
    "PI_MERIDIAN_LISTEN_PORT"
  );
  const server = createProxyServer({ targetPort, logger });

  server.listen(listenPort, DEFAULT_LISTEN_HOST, () => {
    logger.error(
      `Pi → Meridian rewrite proxy listening on http://${DEFAULT_LISTEN_HOST}:${listenPort}`
    );
    logger.error(`Forwarding to http://${DEFAULT_TARGET_HOST}:${targetPort}`);
  });

  return server;
}

const isMainModule =
  process.argv[1] !== undefined &&
  import.meta.url === pathToFileURL(process.argv[1]).href;

if (isMainModule) {
  try {
    const server = startProxyFromEnvironment();
    server.on("error", (error) => {
      console.error(`Pi → Meridian rewrite proxy failed: ${String(error)}`);
      process.exitCode = 1;
    });
  } catch (error) {
    console.error(`Pi → Meridian rewrite proxy failed: ${String(error)}`);
    process.exitCode = 1;
  }
}
