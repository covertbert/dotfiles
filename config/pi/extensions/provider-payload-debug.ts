import { appendFileSync } from "node:fs";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type ToolLike = { name?: unknown };
type ContentLike = { type?: unknown; name?: unknown; arguments?: unknown };

const TASK_TOOL_RE = /^(TaskCreate|TaskUpdate|TaskList|TaskGet|TodoWrite)$/;

function safeStringify(value: unknown): string {
  try {
    return JSON.stringify(value, null, 2);
  } catch (error) {
    return JSON.stringify(
      { error: error instanceof Error ? error.message : String(error) },
      null,
      2
    );
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("before_provider_request", (event, ctx) => {
    const payload = event.payload as { tools?: ToolLike[]; system?: unknown };
    const toolNames = Array.isArray(payload.tools)
      ? payload.tools.map((tool) => String(tool.name ?? "<unnamed>"))
      : [];
    const systemText = safeStringify(payload.system ?? "");

    appendFileSync(
      join(ctx.cwd, ".pi-provider-payload-debug.log"),
      safeStringify({
        kind: "BEFORE_PROVIDER_REQUEST",
        timestamp: new Date().toISOString(),
        model: ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : undefined,
        toolNames,
        advertisedTaskTools: toolNames.filter((name) =>
          TASK_TOOL_RE.test(name)
        ),
        systemMentionsTaskTools:
          /TaskCreate|TaskUpdate|TaskList|TaskGet|TodoWrite/.test(systemText)
      }) + "\n\n",
      "utf8"
    );
  });

  pi.on("message_end", (event, ctx) => {
    if (event.message.role !== "assistant") return;

    const calls = event.message.content
      .filter((block: ContentLike) => block.type === "toolCall")
      .map((block: ContentLike) => ({
        name: String(block.name ?? "<unnamed>"),
        args: block.arguments
      }));

    if (calls.length === 0) return;

    appendFileSync(
      join(ctx.cwd, ".pi-provider-payload-debug.log"),
      "ASSISTANT_TOOL_CALLS\n" +
        safeStringify({
          timestamp: new Date().toISOString(),
          model: ctx.model
            ? `${ctx.model.provider}/${ctx.model.id}`
            : undefined,
          calls,
          taskCalls: calls.filter((call) => TASK_TOOL_RE.test(call.name))
        }) +
        "\n\n",
      "utf8"
    );
  });
}
