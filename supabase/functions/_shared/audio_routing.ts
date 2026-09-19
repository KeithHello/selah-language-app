import {
  AUDIO_FORMAT,
  TTS_MODEL,
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

const NATIVE_PROSODY: Record<
  string,
  { rate: string; pitch: string }
> = {
  "native-gentle": { rate: "0%", pitch: "0%" },
  "native-clear": { rate: "-5%", pitch: "0%" },
  "native-bright": { rate: "+5%", pitch: "+1st" },
  "native-calm": { rate: "-8%", pitch: "-1st" },
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

  if (language === "zh-Hant") {
    if (requestedAccent != null && requestedAccent !== "zh-TW") {
      return {
        ok: false,
        code: "accent_language_mismatch",
        message: "Traditional Chinese audio requires the zh-TW accent",
      };
    }
    if (!voiceProfile.startsWith("native-")) {
      return {
        ok: false,
        code: "voice_role_mismatch",
        message: "Chinese source audio requires a native voice profile",
      };
    }
    return {
      ok: true,
      route: {
        provider: "azure",
        audioRole: input.audioRole,
        language,
        accent: "zh-TW",
        voiceProfile,
        providerVoice: `${AZURE_ZH_TW_VOICE}@${voiceProfile}`,
        providerModel: `azure-speech/${AZURE_ZH_TW_VOICE}`,
        speed: TTS_SPEED,
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
    return {
      ok: true,
      route: {
        provider: "openai",
        audioRole: input.audioRole,
        language,
        accent: expectedAccent,
        voiceProfile,
        providerVoice,
        providerModel: `openai/${TTS_MODEL}/${providerVoice}`,
        speed: TTS_SPEED,
        format: AUDIO_FORMAT,
      },
    };
  }

  // Japanese remains on the existing OpenAI path for this phase.  It is
  // deliberately explicit so it cannot be mistaken for Azure Chinese audio.
  if (requestedAccent != null && requestedAccent !== "ja-JP") {
    return {
      ok: false,
      code: "accent_language_mismatch",
      message: "Japanese audio requires the ja-JP accent",
    };
  }
  return {
    ok: true,
    route: {
      provider: "openai",
      audioRole: input.audioRole,
      language,
      accent: "ja-JP",
      voiceProfile,
      providerVoice,
      providerModel: `openai/${TTS_MODEL}/${providerVoice}`,
      speed: TTS_SPEED,
      format: AUDIO_FORMAT,
    },
  };
}

export function audioCacheKey(input: {
  provider: AudioProvider;
  providerVoice: string;
  speed: number;
  textHash: string;
}): string {
  return `${input.provider}:${input.providerVoice}:${input.speed}:${input.textHash}`;
}

export function buildAzureSsml(text: string, route: AudioRoute): string {
  const baseVoice = route.providerVoice.split("@", 1)[0];
  const profile = NATIVE_PROSODY[route.voiceProfile] ??
    NATIVE_PROSODY["native-gentle"];
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
  return `<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="zh-TW"><voice name="${baseVoice}"><prosody rate="${profile.rate}" pitch="${profile.pitch}">${escaped}</prosody></voice></speak>`;
}
