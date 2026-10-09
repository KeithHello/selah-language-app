import { type AudioRoute, buildAzureSsml } from "./audio_routing.ts";

export const AZURE_OUTPUT_FORMAT = "audio-24khz-160kbitrate-mono-mp3";

export function azureSpeechEndpoint(region: string): string {
  const normalized = region.trim().toLowerCase();
  if (!/^[a-z0-9-]+$/.test(normalized)) {
    throw new Error("invalid_azure_region");
  }
  return `https://${normalized}.tts.speech.microsoft.com/cognitiveservices/v1`;
}

export function buildAzureSpeechRequest(
  text: string,
  route: AudioRoute,
  key: string,
  region: string,
  options: { applyVolume?: boolean } = {},
): { url: string; init: RequestInit } {
  return {
    url: azureSpeechEndpoint(region),
    init: {
      method: "POST",
      headers: {
        "Ocp-Apim-Subscription-Key": key,
        "Content-Type": "application/ssml+xml",
        "X-Microsoft-OutputFormat": AZURE_OUTPUT_FORMAT,
        "User-Agent": "selah-audio-generate",
      },
      body: buildAzureSsml(text, route, options),
    },
  };
}

export function azureBillableCharacterCount(
  text: string,
  route: AudioRoute,
  options: { applyVolume?: boolean } = {},
): number {
  const ssml = buildAzureSsml(text, route, options);
  const voiceContent = ssml.match(/<voice\b[^>]*>([\s\S]*)<\/voice>/)?.[1];
  if (voiceContent === undefined) {
    throw new Error("invalid_azure_ssml_voice_content");
  }
  const decoded = voiceContent.replace(
    /&(amp|lt|gt|quot|apos);/g,
    (_, entity: string) =>
      ({ amp: "&", lt: "<", gt: ">", quot: '"', apos: "'" })[entity] ?? _,
  );
  let characters = 0;
  for (const character of decoded) {
    characters += /\p{Script=Han}/u.test(character) ? 2 : 1;
  }
  return characters;
}
