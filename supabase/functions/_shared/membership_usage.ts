export interface MembershipReservationUsageRow {
  feature: string;
  units_reserved: number;
  status: string;
}

export interface MembershipUsageBucket {
  used: number;
  reserved: number;
}

export interface MembershipUsage {
  sentence: MembershipUsageBucket;
  batch: MembershipUsageBucket;
  ttsCharacters: MembershipUsageBucket;
  transcriptionMs: MembershipUsageBucket;
  preparations: MembershipUsageBucket;
}

const ACTIVE_STATUSES = new Set([
  "reserved",
  "dispatch_claimed",
  "unknown",
]);

export function aggregateMembershipUsage(
  rows: readonly MembershipReservationUsageRow[],
): MembershipUsage {
  const usage: MembershipUsage = {
    sentence: { used: 0, reserved: 0 },
    batch: { used: 0, reserved: 0 },
    ttsCharacters: { used: 0, reserved: 0 },
    transcriptionMs: { used: 0, reserved: 0 },
    preparations: { used: 0, reserved: 0 },
  };

  for (const row of rows) {
    const bucket = row.feature === "sentence" || row.feature === "batch"
      ? usage[row.feature]
      : row.feature === "tts"
      ? usage.ttsCharacters
      : row.feature === "transcription"
      ? usage.transcriptionMs
      : row.feature === "preparation"
      ? usage.preparations
      : null;
    if (!bucket || !Number.isFinite(row.units_reserved)) continue;
    if (row.status === "settled") {
      bucket.used += row.units_reserved;
    } else if (ACTIVE_STATUSES.has(row.status)) {
      bucket.reserved += row.units_reserved;
    }
  }

  return usage;
}
