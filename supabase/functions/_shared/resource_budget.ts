// Resource budget and download gateway security policies.

export const MAX_AUDIO_BYTE_SIZE = 5 * 1024 * 1024; // 5 MiB ceiling for TTS MP3 files

export interface RangeHeaderParseResult {
  valid: boolean;
  start?: number;
  end?: number;
  isMultiRange: boolean;
}

/**
 * Safely parse HTTP Range header. Rejects multi-range requests to prevent amplification attacks.
 */
export function parseSingleByteRange(rangeHeader: string | null, totalSize: number): RangeHeaderParseResult {
  if (!rangeHeader) {
    return { valid: true, start: 0, end: totalSize - 1, isMultiRange: false };
  }
  if (rangeHeader.includes(",")) {
    return { valid: false, isMultiRange: true };
  }
  const match = /^bytes=(\d*)-(\d*)$/i.exec(rangeHeader.trim());
  if (!match) {
    return { valid: false, isMultiRange: false };
  }
  const rawStart = match[1];
  const rawEnd = match[2];
  let start = rawStart ? Number.parseInt(rawStart, 10) : 0;
  let end = rawEnd ? Number.parseInt(rawEnd, 10) : totalSize - 1;

  if (rawStart === "" && rawEnd !== "") {
    // Suffix range: -N means last N bytes
    const suffix = Number.parseInt(rawEnd, 10);
    start = Math.max(0, totalSize - suffix);
    end = totalSize - 1;
  }

  if (start > end || start >= totalSize || end >= totalSize || start < 0) {
    return { valid: false, isMultiRange: false };
  }

  return { valid: true, start, end, isMultiRange: false };
}
