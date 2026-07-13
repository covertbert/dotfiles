export interface NormalizedQuotaWindow {
  /** Remaining quota as percentage: 0 = empty, 100 = full. */
  remainingPct: number;
  /** ISO timestamp for reset, or null when unknown/not applicable. */
  resetAt: string | null;
}

export interface NormalizedQuotaUsage {
  fiveHour: NormalizedQuotaWindow | null;
  weekly: NormalizedQuotaWindow | null;
}

export type QuotaResult =
  | {
      status: "ok";
      display: string;
      usage: NormalizedQuotaUsage;
      source: string;
    }
  | {
      status: "partial";
      display: string;
      usage: NormalizedQuotaUsage;
      source: string;
    }
  | { status: "unknown"; reason?: string; source?: string };

export interface QuotaAdapter {
  readonly name: string;
  fetch(params?: { cwd?: string; signal?: AbortSignal }): Promise<QuotaResult>;
  debug?(): Record<string, unknown>;
}
