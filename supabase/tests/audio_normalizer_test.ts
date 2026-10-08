import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { sha256 } from "../functions/_shared/audio.ts";
import {
  AUDIO_NORMALIZER_REVISION,
  AudioNormalizationError,
  normalizeAudioBuffer,
} from "../functions/_shared/audio_normalizer.ts";

const TOKEN = "normalizer-test-token-that-is-long-enough";

function mp3Buffer(byte = 1): ArrayBuffer {
  const audio = new Uint8Array(1024);
  audio.set([0x49, 0x44, 0x33]);
  audio.fill(byte, 3);
  return audio.buffer;
}

async function normalizedResponse(
  audio: ArrayBuffer,
  overrides: Record<string, string> = {},
): Promise<Response> {
  return new Response(audio, {
    status: 200,
    headers: {
      "Content-Type": "audio/mpeg",
      "X-Audio-Normalizer-Revision": AUDIO_NORMALIZER_REVISION,
      "X-Audio-SHA256": await sha256(audio),
      "X-Audio-Integrated-Lufs": "-22.0",
      "X-Audio-True-Peak-Dbtp": "-1.2",
      "X-Audio-Duration-Ms": "1000",
      "X-Audio-Sample-Rate": "24000",
      "X-Audio-Channels": "1",
      "X-Audio-Normalization-Mode": "linear",
      ...overrides,
    },
  });
}

Deno.test("normalizer request binds bearer token, body digest and revision", async () => {
  const source = mp3Buffer();
  const output = mp3Buffer(2);
  let requestUrl = "";
  let requestInit: RequestInit | undefined;
  const result = await normalizeAudioBuffer(source, {
    endpoint: "https://normalizer.example.test",
    token: TOKEN,
    fetch: async (input, init) => {
      requestUrl = String(input);
      requestInit = init;
      return await normalizedResponse(output);
    },
  });
  const headers = new Headers(requestInit?.headers);
  assertEquals(requestUrl, "https://normalizer.example.test/v1/normalize");
  assertEquals(headers.get("Authorization"), "Bearer " + TOKEN);
  assertEquals(headers.get("Content-Type"), "audio/mpeg");
  assertEquals(headers.get("X-Audio-SHA256"), await sha256(source));
  assertEquals(
    headers.get("X-Audio-Normalizer-Revision"),
    AUDIO_NORMALIZER_REVISION,
  );
  assertEquals(result.sha256, await sha256(output));
  assertEquals(result.integratedLufs, -22);
});

Deno.test("normalizer client rejects insecure URLs and short tokens", async () => {
  await assertRejects(
    () =>
      normalizeAudioBuffer(mp3Buffer(), {
        endpoint: "http://normalizer.example.test",
        token: TOKEN,
        fetch: async () => await normalizedResponse(mp3Buffer()),
      }),
    AudioNormalizationError,
    "normalizer_url_invalid",
  );
  await assertRejects(
    () =>
      normalizeAudioBuffer(mp3Buffer(), {
        endpoint: "https://normalizer.example.test",
        token: "short",
        fetch: async () => await normalizedResponse(mp3Buffer()),
      }),
    AudioNormalizationError,
    "normalizer_token_unconfigured",
  );
});

Deno.test("normalizer client rejects loudness values outside its contract", async () => {
  await assertRejects(
    () =>
      normalizeAudioBuffer(mp3Buffer(), {
        endpoint: "https://normalizer.example.test",
        token: TOKEN,
        fetch: async () =>
          await normalizedResponse(mp3Buffer(2), {
            "X-Audio-True-Peak-Dbtp": "-0.5",
          }),
      }),
    AudioNormalizationError,
    "normalizer_measurement_out_of_range",
  );
});

Deno.test("normalizer client rejects a response whose checksum does not match", async () => {
  await assertRejects(
    () =>
      normalizeAudioBuffer(mp3Buffer(), {
        endpoint: "https://normalizer.example.test",
        token: TOKEN,
        fetch: async () =>
          await normalizedResponse(mp3Buffer(2), {
            "X-Audio-SHA256": "0".repeat(64),
          }),
      }),
    AudioNormalizationError,
    "normalizer_digest_mismatch",
  );
});
