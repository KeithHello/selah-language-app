import {
  AUDIO_FORMAT,
  AUDIO_NORMALIZER_REVISION,
  TTS_SPEED,
  VOICE_ACCENTS,
  VOICE_MAP,
} from "./audio.ts";

export type AudioRole = "source" | "target";
export type AudioProvider = "azure" | "openai";
export type AudioAccent = "zh-TW" | "ja-JP" | "en-US" | "en-GB";

export interface AudioRoute {
  provider: AudioProvider;
  audioRole: AudioRole;
  language: "zh-Hant" | "ja" | "en";
  accent: AudioAccent;
  voiceProfile: string;
  providerVoice: string;
  providerModel: string;
  speed: number;
  format: string;
}

export type AudioRouteResult =
  | { ok: true; route: AudioRoute }
  | { ok: false; code: string; message: string };

const AZURE_ZH_TW_VOICE = "zh-TW-HsiaoChenNeural";
const AZURE_JA_JP_VOICE = "ja-JP-NanamiNeural";
const AZURE_EN_US_JENNY = "en-US-JennyNeural";
const AZURE_EN_US_GUY = "en-US-GuyNeural";
const AZURE_EN_GB_SONIA = "en-GB-SoniaNeural";

const PROFILE_PROSODY: Record<
  string,
  { rate: string; pitch: string; speed: number }
> = {
  "gentle-natural": { rate: "0%", pitch: "0%", speed: TTS_SPEED },
  "clear-slow": { rate: "-10%", pitch: "0%", speed: 0.9 },
  "daily-bright": { rate: "+5%", pitch: "+1st", speed: 1.05 },
  "elegant-british": { rate: "0%", pitch: "0%", speed: TTS_SPEED },
  "native-gentle": { rate: "0%", pitch: "0%", speed: TTS_SPEED },
  "native-clear": { rate: "-5%", pitch: "0%", speed: 0.95 },
  "native-bright": { rate: "+5%", pitch: "+1st", speed: 1.05 },
  "native-calm": { rate: "-8%", pitch: "-1st", speed: 0.92 },
};

function canonicalLanguage(value: unknown): "zh-Hant" | "ja" | "en" | null {
  if (typeof value !== "string") return null;
  switch (value.trim()) {
    case "zh":
    case "zh-Hant":
    case "zh-Hans":
    case "zh-TW":
      return "zh-Hant";
    case "ja":
    case "ja-JP":
      return "ja";
    case "en":
    case "en-US":
    case "en-GB":
      return "en";
    default:
      return null;
  }
}

function canonicalAccent(value: unknown): AudioAccent | null {
  if (value === undefined || value === null || value === "") return null;
  if (
    value === "zh-TW" || value === "ja-JP" || value === "en-US" ||
    value === "en-GB"
  ) {
    return value;
  }
  return null;
}

export function resolveAudioRoute(input: {
  audioRole?: AudioRole;
  sourceLanguage?: string;
  targetLanguage?: string;
  accent?: string;
  voiceProfile?: string;
}): AudioRouteResult {
  if (input.audioRole !== "source" && input.audioRole !== "target") {
    return {
      ok: false,
      code: "missing_audio_role",
      message: "audioRole must be source or target",
    };
  }

  const voiceProfile = input.voiceProfile ??
    (input.audioRole === "source" ? "native-gentle" : "gentle-natural");
  const providerVoice = VOICE_MAP[voiceProfile];
  if (!providerVoice) {
    return {
      ok: false,
      code: "unsupported_voice_profile",
      message: "Unsupported voice profile",
    };
  }
  const profileProsody = PROFILE_PROSODY[voiceProfile];
  if (!profileProsody) {
    return {
      ok: false,
      code: "unsupported_voice_profile",
      message: "Unsupported voice profile",
    };
  }

  const language = canonicalLanguage(
    input.audioRole === "source" ? input.sourceLanguage : input.targetLanguage,
  );
  if (!language) {
    return {
      ok: false,
      code: "unsupported_audio_language",
      message: "Unsupported spoken language",
    };
  }

  const requestedAccent = canonicalAccent(input.accent);
  if (input.accent != null && input.accent !== "" && !requestedAccent) {
    return {
      ok: false,
      code: "unsupported_accent",
      message: "Unsupported accent",
    };
  }

  if (language === "zh-Hant" || language === "ja") {
    const expectedAccent = language === "zh-Hant" ? "zh-TW" : "ja-JP";
    if (requestedAccent != null && requestedAccent !== expectedAccent) {
      return {
        ok: false,
        code: "accent_language_mismatch",
        message: `${language} audio requires the ${expectedAccent} accent`,
      };
    }
    if (!voiceProfile.startsWith("native-")) {
      return {
        ok: false,
        code: "voice_role_mismatch",
        message: "Chinese source audio requires a native voice profile",
      };
    }
    const baseVoice = language === "zh-Hant"
      ? AZURE_ZH_TW_VOICE
      : AZURE_JA_JP_VOICE;
    return {
      ok: true,
      route: {
        provider: "azure",
        audioRole: input.audioRole,
        language,
        accent: expectedAccent,
        voiceProfile,
        providerVoice: `${baseVoice}@${voiceProfile}`,
        providerModel: `azure-speech/${baseVoice}`,
        speed: profileProsody.speed,
        format: AUDIO_FORMAT,
      },
    };
  }

  if (language === "en") {
    const expectedAccent = VOICE_ACCENTS[voiceProfile];
    if (expectedAccent !== "en-US" && expectedAccent !== "en-GB") {
      return {
        ok: false,
        code: "voice_role_mismatch",
        message: "English target audio requires an English voice profile",
      };
    }
    if (requestedAccent != null && requestedAccent !== expectedAccent) {
      return {
        ok: false,
        code: "accent_voice_mismatch",
        message: "Accent does not match the selected voice profile",
      };
    }
    const azureVoice = voiceProfile === "elegant-british"
      ? AZURE_EN_GB_SONIA
      : voiceProfile === "daily-bright"
      ? AZURE_EN_US_GUY
      : AZURE_EN_US_JENNY;
    return {
      ok: true,
      route: {
        provider: "azure",
        audioRole: input.audioRole,
        language,
        accent: expectedAccent,
        voiceProfile,
        providerVoice: `${azureVoice}@${voiceProfile}`,
        providerModel: `azure-speech/${azureVoice}`,
        speed: profileProsody.speed,
        format: AUDIO_FORMAT,
      },
    };
  }

  return {
    ok: false,
    code: "unsupported_audio_language",
    message: "Unsupported spoken language",
  };
}

export function audioCacheKey(input: {
  provider: AudioProvider;
  providerVoice: string;
  speed: number;
  textHash: string;
  normalizerRevision?: string;
}): string {
  return `${input.provider}:${input.providerVoice}:${input.speed}:${
    input.normalizerRevision ?? AUDIO_NORMALIZER_REVISION
  }:${input.textHash}`;
}

export function buildAzureSsml(text: string, route: AudioRoute): string {
  const baseVoice = route.providerVoice.split("@", 1)[0];
  const profile = PROFILE_PROSODY[route.voiceProfile];
  if (!profile) throw new Error("unsupported_voice_profile");
  const escaped = text.replace(
    /[&<>"']/g,
    (value) => ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&apos;",
    }[value] ?? value),
  );
  return `<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="${route.accent}"><voice name="${baseVoice}" xml:lang="${route.accent}"><prosody rate="${profile.rate}" pitch="${profile.pitch}">${escaped}</prosody></voice></speak>`;
}
