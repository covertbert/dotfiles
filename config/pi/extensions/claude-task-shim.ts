import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

type TaskStatus = "pending" | "in_progress" | "completed" | "deleted";

type Task = {
  id: string;
  subject: string;
  description: string;
  activeForm?: string;
  status: TaskStatus;
  metadata?: unknown;
};

const emptyText = () => new Text("", 0, 0);
const silentRender = {
  renderCall: emptyText,
  renderResult: emptyText
};

const jsonContent = (value: unknown) => [
  { type: "text" as const, text: JSON.stringify(value) }
];

export default function (pi: ExtensionAPI) {
  let nextId = 1;
  const tasks = new Map<string, Task>();

  pi.registerTool({
    name: "TaskCreate",
    label: "TaskCreate",
    description:
      "Compatibility shim for Claude Code task tracking in Pi. Creates an in-memory task entry.",
    parameters: Type.Object(
      {
        subject: Type.String(),
        description: Type.Optional(Type.String()),
        activeForm: Type.Optional(Type.String()),
        metadata: Type.Optional(Type.Any())
      },
      { additionalProperties: true }
    ),
    async execute(_toolCallId, params) {
      const id = String(nextId++);
      const task: Task = {
        id,
        subject: params.subject,
        description: params.description ?? "",
        activeForm: params.activeForm,
        status: "pending",
        metadata: params.metadata
      };
      tasks.set(id, task);
      return {
        content: jsonContent({ task }),
        details: { task }
      };
    },
    ...silentRender
  });

  pi.registerTool({
    name: "TaskUpdate",
    label: "TaskUpdate",
    description:
      "Compatibility shim for Claude Code task tracking in Pi. Updates an in-memory task entry.",
    parameters: Type.Object(
      {
        taskId: Type.String(),
        status: Type.Optional(Type.String()),
        subject: Type.Optional(Type.String()),
        description: Type.Optional(Type.String()),
        activeForm: Type.Optional(Type.String()),
        owner: Type.Optional(Type.String()),
        metadata: Type.Optional(Type.Any()),
        addBlocks: Type.Optional(Type.Array(Type.String())),
        addBlockedBy: Type.Optional(Type.Array(Type.String()))
      },
      { additionalProperties: true }
    ),
    prepareArguments(args) {
      if (!args || typeof args !== "object") return args;
      const input = args as Record<string, unknown>;
      return {
        ...input,
        taskId: input.taskId ?? input.id ?? input.task_id,
        activeForm: input.activeForm ?? input.active_form
      };
    },
    async execute(_toolCallId, params) {
      const existing = tasks.get(params.taskId) ?? {
        id: params.taskId,
        subject: params.subject ?? params.taskId,
        description: params.description ?? "",
        status: "pending" as TaskStatus
      };

      const status = params.status as TaskStatus | undefined;
      const updated: Task = {
        ...existing,
        subject: params.subject ?? existing.subject,
        description: params.description ?? existing.description,
        activeForm: params.activeForm ?? existing.activeForm,
        status: status ?? existing.status,
        metadata: params.metadata ?? existing.metadata
      };

      if (updated.status === "deleted") {
        tasks.delete(updated.id);
      } else {
        tasks.set(updated.id, updated);
      }

      return {
        content: jsonContent({ task: updated }),
        details: { task: updated }
      };
    },
    ...silentRender
  });

  pi.registerTool({
    name: "TaskList",
    label: "TaskList",
    description:
      "Compatibility shim for Claude Code task tracking in Pi. Lists in-memory tasks.",
    parameters: Type.Object({}, { additionalProperties: true }),
    async execute() {
      const taskList = Array.from(tasks.values());
      return {
        content: jsonContent({ tasks: taskList }),
        details: { tasks: taskList }
      };
    },
    ...silentRender
  });

  pi.registerTool({
    name: "TaskGet",
    label: "TaskGet",
    description:
      "Compatibility shim for Claude Code task tracking in Pi. Gets an in-memory task.",
    parameters: Type.Object(
      { taskId: Type.String() },
      { additionalProperties: true }
    ),
    prepareArguments(args) {
      if (!args || typeof args !== "object") return args;
      const input = args as Record<string, unknown>;
      return { ...input, taskId: input.taskId ?? input.id ?? input.task_id };
    },
    async execute(_toolCallId, params) {
      const task = tasks.get(params.taskId) ?? null;
      return {
        content: jsonContent({ task }),
        details: { task }
      };
    },
    ...silentRender
  });

  pi.registerTool({
    name: "TodoWrite",
    label: "TodoWrite",
    description:
      "Compatibility shim for legacy Claude Code todo tracking in Pi.",
    parameters: Type.Object(
      { todos: Type.Optional(Type.Any()) },
      { additionalProperties: true }
    ),
    async execute(_toolCallId, params) {
      return {
        content: jsonContent({ todos: params.todos ?? [] }),
        details: { todos: params.todos ?? [] }
      };
    },
    ...silentRender
  });
}
