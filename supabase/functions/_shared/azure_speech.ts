import { type AudioRoute, buildAzureSsml } from "./audio_routing.ts";

export const AZURE_OUTPUT_FORMAT = "audio-16khz-128kbitrate-mono-mp3";

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
      body: buildAzureSsml(text, route),
    },
  };
}
