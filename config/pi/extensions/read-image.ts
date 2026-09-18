import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

// Vision is delegated to a multimodal model so a text-only active model
// (e.g. qwen3-8-27b) can still "see" images. The image is sent to the vision
// model over the RunInfra OpenAI-compatible API and the result is returned as
// text to the active model. No model switching required.
const VISION_MODEL = "ornith-1-5-35b";
const VISION_URL = "https://api.runinfra.ai/v1/chat/completions";

const MIME_BY_EXT: Record<string, string> = {
  png: "image/png",
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  gif: "image/gif",
  webp: "image/webp",
  bmp: "image/bmp"
};

async function loadImage(
  source: string
): Promise<{ b64: string; mime: string }> {
  if (/^https?:\/\//i.test(source)) {
    const res = await fetch(source);
    if (!res.ok)
      throw new Error(`fetch failed: HTTP ${res.status} for ${source}`);
    const mime = res.headers.get("content-type") || "image/png";
    const buf = Buffer.from(await res.arrayBuffer());
    return { b64: buf.toString("base64"), mime: mime.split(";")[0].trim() };
  }
  const fs = await import("node:fs/promises");
  const buf = await fs.readFile(source);
  const ext = source.toLowerCase().split(".").pop() || "";
  return { b64: buf.toString("base64"), mime: MIME_BY_EXT[ext] || "image/png" };
}

export default function readImageExtension(pi: ExtensionAPI) {
  pi.registerTool({
    name: "read_image",
    label: "Read Image",
    description:
      "View an image from an http(s) URL or a local file path. The active model is text-only and cannot see images directly; this tool sends the image to a vision model (Ornith) and returns its description and any transcribed text.",
    promptSnippet:
      "View an image (URL or path) via a vision model, returning its contents as text.",
    promptGuidelines: [
      "You are text-only and cannot view images yourself. Whenever the user shares, drops, or references an image (an http(s) URL or a file path) and you need its contents, call read_image with that URL or path. Do not guess what an image shows."
    ],
    parameters: Type.Object({
      source: Type.String({
        description: "Image URL (http/https) or local file path"
      }),
      prompt: Type.Optional(
        Type.String({
          description:
            "Optional: what to extract from the image. Defaults to a full description plus exact transcription of all visible text."
        })
      )
    }),
    async execute(_toolCallId, params, signal) {
      const key = process.env.RUNINFRA_KEY || "";
      if (!key) {
        return {
          content: [
            {
              type: "text",
              text: "read_image: RUNINFRA_KEY is not set in the environment."
            }
          ],
          details: {},
          isError: true
        };
      }
      let b64: string;
      let mime: string;
      try {
        ({ b64, mime } = await loadImage(params.source));
      } catch (e: any) {
        return {
          content: [
            {
              type: "text",
              text: `read_image: could not load image: ${e?.message || e}`
            }
          ],
          details: {},
          isError: true
        };
      }

      const instruction =
        params.prompt ||
        "Describe this image in detail for a coding assistant. Transcribe ALL visible text exactly (UI labels, errors, logs, code, values). Note layout, colors, and any visible state or selections.";

      try {
        const res = await fetch(VISION_URL, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${key}`,
            "Content-Type": "application/json"
          },
          body: JSON.stringify({
            model: VISION_MODEL,
            max_tokens: 4000,
            messages: [
              {
                role: "user",
                content: [
                  { type: "text", text: instruction },
                  {
                    type: "image_url",
                    image_url: { url: `data:${mime};base64,${b64}` }
                  }
                ]
              }
            ]
          }),
          signal
        });
        if (!res.ok) {
          const body = await res.text().catch(() => "");
          return {
            content: [
              {
                type: "text",
                text: `read_image: vision API HTTP ${res.status}: ${body.slice(0, 400)}`
              }
            ],
            details: {},
            isError: true
          };
        }
        const data = (await res.json()) as any;
        const text =
          data?.choices?.[0]?.message?.content ?? "(no content returned)";
        return {
          content: [
            { type: "text", text: `Image read via ${VISION_MODEL}:\n\n${text}` }
          ],
          details: { model: VISION_MODEL, source: params.source }
        };
      } catch (e: any) {
        return {
          content: [
            {
              type: "text",
              text: `read_image: request failed: ${e?.message || e}`
            }
          ],
          details: {},
          isError: true
        };
      }
    }
  });
}
