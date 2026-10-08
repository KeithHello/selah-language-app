import { AUDIO_NORMALIZER_REVISION, sha256 } from "./audio.ts";
import { isLikelyMp3Audio } from "./audio_generation_policy.ts";

export { AUDIO_NORMALIZER_REVISION };

export const AUDIO_NORMALIZER_MAX_BYTES = 10 * 1024 * 1024;
export const AUDIO_NORMALIZER_TIMEOUT_MS = 60 * 1_000;

export interface NormalizedAudio {
  audio: ArrayBuffer;
  sha256: string;
  integratedLufs: number;
  truePeakDbtp: number;
  durationMs: number;
  mode: "linear" | "dynamic";
  revision: string;
}

export class AudioNormalizationError extends Error {
  constructor(readonly code: string) {
    super(code);
    this.name = "AudioNormalizationError";
  }
}

function normalizerEndpoint(value: string): string {
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new AudioNormalizationError("normalizer_url_invalid");
  }
  if (
    url.protocol !== "https:" || url.username || url.password ||
    url.search || url.hash
  ) {
    throw new AudioNormalizationError("normalizer_url_invalid");
  }
  url.pathname = url.pathname.replace(/\/+$/, "") + "/v1/normalize";
  return url.toString();
}

export function isAudioNormalizerConfigured(
  endpoint: string,
  token: string,
): boolean {
  if (token.length < 32) return false;
  try {
    normalizerEndpoint(endpoint);
    return true;
  } catch {
    return false;
  }
}

function headerNumber(response: Response, name: string): number {
  const value = Number(response.headers.get(name));
  if (!Number.isFinite(value)) {
    throw new AudioNormalizationError("normalizer_metadata_invalid");
  }
  return value;
}

async function readLimitedAudio(response: Response): Promise<ArrayBuffer> {
  const lengthHeader = response.headers.get("Content-Length");
  if (lengthHeader !== null) {
    const length = Number(lengthHeader);
    if (
      !Number.isSafeInteger(length) || length < 512 ||
      length > AUDIO_NORMALIZER_MAX_BYTES
    ) {
      throw new AudioNormalizationError("normalizer_audio_size_invalid");
    }
  }
  if (!response.body) {
    throw new AudioNormalizationError("normalizer_audio_missing");
  }
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let length = 0;
  try {
    while (true) {
      const result = await reader.read();
      if (result.done) break;
      length += result.value.byteLength;
      if (length > AUDIO_NORMALIZER_MAX_BYTES) {
        await reader.cancel();
        throw new AudioNormalizationError("normalizer_audio_size_invalid");
      }
      chunks.push(result.value);
    }
  } finally {
    reader.releaseLock();
  }
  if (length < 512) {
    throw new AudioNormalizationError("normalizer_audio_size_invalid");
  }
  const audio = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    audio.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return audio.buffer;
}

export async function normalizeAudioBuffer(
  source: ArrayBuffer,
  options: {
    endpoint: string;
    token: string;
    fetch?: typeof fetch;
  },
): Promise<NormalizedAudio> {
  if (!isLikelyMp3Audio(source)) {
    throw new AudioNormalizationError("audio_source_invalid");
  }
  if (source.byteLength > AUDIO_NORMALIZER_MAX_BYTES) {
    throw new AudioNormalizationError("audio_source_too_large");
  }
  if (options.token.length < 32) {
    throw new AudioNormalizationError("normalizer_token_unconfigured");
  }
  const endpoint = normalizerEndpoint(options.endpoint);
  const sourceDigest = await sha256(source);
  let response: Response;
  try {
    response = await (options.fetch ?? fetch)(endpoint, {
      method: "POST",
      headers: {
        Authorization: "Bearer " + options.token,
        "Content-Type": "audio/mpeg",
        "X-Audio-SHA256": sourceDigest,
        "X-Audio-Normalizer-Revision": AUDIO_NORMALIZER_REVISION,
      },
      body: source,
      signal: AbortSignal.timeout(AUDIO_NORMALIZER_TIMEOUT_MS),
    });
  } catch {
    throw new AudioNormalizationError("normalizer_unavailable");
  }
  if (!response.ok) {
    throw new AudioNormalizationError("normalizer_http_" + response.status);
  }
  if (
    response.headers.get("Content-Type")?.split(";", 1)[0].trim()
        .toLowerCase() !==
      "audio/mpeg" ||
    response.headers.get("X-Audio-Normalizer-Revision") !==
      AUDIO_NORMALIZER_REVISION
  ) {
    throw new AudioNormalizationError("normalizer_response_invalid");
  }

  const integratedLufs = headerNumber(
    response,
    "X-Audio-Integrated-Lufs",
  );
  const truePeakDbtp = headerNumber(response, "X-Audio-True-Peak-Dbtp");
  const durationMs = headerNumber(response, "X-Audio-Duration-Ms");
  const sampleRate = headerNumber(response, "X-Audio-Sample-Rate");
  const channels = headerNumber(response, "X-Audio-Channels");
  const mode = response.headers.get("X-Audio-Normalization-Mode");
  if (
    integratedLufs < -23 || integratedLufs > -21 ||
    truePeakDbtp > -1 || durationMs <= 0 || durationMs > 600_000 ||
    sampleRate !== 24_000 || channels !== 1 ||
    (mode !== "linear" && mode !== "dynamic")
  ) {
    throw new AudioNormalizationError("normalizer_measurement_out_of_range");
  }

  const audio = await readLimitedAudio(response);
  if (!isLikelyMp3Audio(audio)) {
    throw new AudioNormalizationError("normalizer_audio_invalid");
  }
  const digest = await sha256(audio);
  if (digest !== response.headers.get("X-Audio-SHA256")) {
    throw new AudioNormalizationError("normalizer_digest_mismatch");
  }
  return {
    audio,
    sha256: digest,
    integratedLufs,
    truePeakDbtp,
    durationMs,
    mode,
    revision: AUDIO_NORMALIZER_REVISION,
  };
}
