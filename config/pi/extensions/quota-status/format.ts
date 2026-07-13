import type {
  NormalizedQuotaUsage,
  NormalizedQuotaWindow
} from "./adapters/types.ts";

export interface ThemeLike {
  fg?(color: string, text: string): string;
}

type StatusLevel = "normal" | "warning" | "error";

const MUTED_STATUS_COLORS: Record<
  StatusLevel,
  readonly [number, number, number]
> = {
  normal: [143, 181, 115],
  warning: [219, 188, 127],
  error: [230, 126, 128]
};

function mutedFg(level: StatusLevel, text: string): string {
  const [r, g, b] = MUTED_STATUS_COLORS[level];
  return `\x1b[38;2;${r};${g};${b}m${text}\x1b[39m`;
}

function clampPct(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(100, value));
}

export function remainingFromUsed(usedPct: number): number {
  return clampPct(100 - usedPct);
}

export function formatDuration(ms: number): string {
  const minutes = Math.max(0, ms / 60_000);
  if (minutes >= 1440) return `${(minutes / 1440).toFixed(2)}d`;
  if (minutes >= 60) {
    const totalMinutes = Math.round(minutes);
    const hours = Math.floor(totalMinutes / 60);
    const remainingMinutes = totalMinutes % 60;
    return remainingMinutes === 0
      ? `${hours}h`
      : `${hours}h${remainingMinutes}m`;
  }
  return `${minutes.toFixed(0)}min`;
}

export function resetDuration(resetAt: string | null, nowMs: number): string {
  if (!resetAt) return "??";
  const resetMs = Date.parse(resetAt);
  if (!Number.isFinite(resetMs)) return "??";
  return formatDuration(Math.max(0, resetMs - nowMs));
}

export function formatWindow(
  window: NormalizedQuotaWindow | null,
  nowMs: number
): string {
  if (!window) return "??, ??";
  return `${clampPct(window.remainingPct).toFixed(0)}%, ${resetDuration(window.resetAt, nowMs)}`;
}

export function formatUsage(
  usage: NormalizedQuotaUsage,
  nowMs: number = Date.now()
): string {
  return `5h(${formatWindow(usage.fiveHour, nowMs)}) Wk(${formatWindow(usage.weekly, nowMs)})`;
}

export function statusLevel(
  usage: NormalizedQuotaUsage | undefined
): StatusLevel {
  const values = [
    usage?.fiveHour?.remainingPct,
    usage?.weekly?.remainingPct
  ].filter(
    (value): value is number =>
      typeof value === "number" && Number.isFinite(value)
  );
  if (values.some((value) => value < 10)) return "error";
  if (values.some((value) => value < 30)) return "warning";
  return "normal";
}

export function styleStatus(
  label: string,
  theme?: ThemeLike,
  level: StatusLevel | "dim" = "normal"
): string {
  if (level !== "dim") return mutedFg(level, label);

  try {
    return theme?.fg ? theme.fg("dim", label) : label;
  } catch {
    return label;
  }
}
