export const EVENT_METADATA_KEYS: Record<string, ReadonlySet<string>> = {
  sentence_created: new Set(["category", "origin"]),
  listen_started: new Set(["speed"]),
  listen_completed: new Set(["duration_ms"]),
  practice_started: new Set(),
  practice_rated: new Set(["signal"]),
  preview_completed: new Set(),
  vocab_added: new Set(["word"]),
  vocab_removed: new Set(["word"]),
  voice_selected: new Set(["voice_profile"]),
  memory_unlocked: new Set(["memory_key"]),
  activity_heartbeat: new Set([
    "session_id",
    "slot_start",
    "duration_ms",
    "visible",
    "audio_playing",
  ]),
  feedback_invite_shown: new Set([
    "survey_version",
    "stage",
    "display_locale",
  ]),
  feedback_invite_dismissed: new Set([
    "survey_version",
    "stage",
    "display_locale",
  ]),
  feedback_submitted: new Set([
    "survey_version",
    "stage",
    "display_locale",
    "satisfaction",
    "scenario",
    "improvement",
    "purchase_intent",
    "plan_interest",
  ]),
  feedback_plan_viewed: new Set([
    "survey_version",
    "stage",
    "display_locale",
    "plan_id",
  ]),
};

export const ALLOWED_EVENT_TYPES = new Set(Object.keys(EVENT_METADATA_KEYS));

export function sanitizeEventMetadata(
  eventType: string,
  metadata: Record<string, unknown> | undefined,
): Record<string, string | number | boolean> {
  const allowedKeys = EVENT_METADATA_KEYS[eventType];
  if (!allowedKeys || !metadata) return {};

  const safe: Record<string, string | number | boolean> = {};
  for (const [key, value] of Object.entries(metadata)) {
    if (!allowedKeys.has(key)) continue;
    if (typeof value === "string" && value.length <= 200) {
      safe[key] = value;
    } else if (typeof value === "number" && Number.isFinite(value)) {
      safe[key] = value;
    } else if (typeof value === "boolean") {
      safe[key] = value;
    }
  }
  return safe;
}
